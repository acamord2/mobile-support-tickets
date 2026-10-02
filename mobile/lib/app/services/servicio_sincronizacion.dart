import 'dart:async';
import 'package:get/get.dart';
import '../database/repositorio_coordinacion.dart';
import '../database/repositorio_solicitudes.dart';
import '../database/repositorio_cola.dart';
import '../database/repositorio_tickets.dart';
import '../database/repositorio_sucursales.dart';
import '../database/repositorio_evidencias.dart';
import '../database/repositorio_eventos.dart';
import '../database/operaciones_sqlite.dart';
import '../database/operacion_pendiente.dart';
import '../database/resultado_sqlite.dart';
import '../network/i_conexion_api.dart';
import '../network/respuesta_api.dart';
import '../network/estado_api.dart';
import '../network/rutas_api.dart';
import 'servicio_conectividad.dart';
import 'servicio_sesion.dart';

/// Diferencia resultados reales de envío, pendientes y falta de acceso remoto.
enum EstadoSincronizacionActual {
  inactivo,
  sincronizando,
  actualizado,
  pendientes,
  offline,
  error,
  reautenticacion,
}

/// Sube únicamente operaciones propias y descarga a SQLite; nunca entrega objetos
/// HTTP a Home. Serializa ciclos sin polling y conserva reintentos tras interrupciones.
class ServicioSincronizacion extends GetxService {
  final ServicioConectividad _conectividad;
  final IConexionApi _api;
  final RepositorioCola _cola;
  final ServicioSesion _sesion;
  final RepositorioTickets? tickets;
  final RepositorioSucursales? sucursales;
  final RepositorioEvidencias? evidencias;
  final apiDisponible = Rxn<bool>();
  final estado = EstadoSincronizacionActual.inactivo.obs;
  Future<void>? _ciclo;
  bool _otroIntento = false;
  ServicioSincronizacion(
    this._conectividad,
    this._api,
    this._cola,
    this._sesion, {
    this.tickets,
    this.sucursales,
    this.evidencias,
  });
  bool get puedeIntentarEnvio => !_conectividad.sinRed && _sesion.token != null;
  Future<void> registrarEstadoProtegido(int? estado) async {
    if (estado == EstadoApi.unauthorized) await _sesion.marcarReautenticacion();
  }

  Future<ResultadoSqlite<List<OperacionPendiente>>> consultarPendientes() =>
      _sesion.usuario == null
      ? Future.value(const ResultadoSqlite.exito(<OperacionPendiente>[]))
      : _cola.obtenerPendientes(usuarioId: _sesion.usuario!.id);
  Future<bool> comprobarDisponibilidadApi() async {
    if (_conectividad.sinRed) return apiDisponible.value = false;
    try {
      final r = await _api.get(RutasApi.healthDatabase);
      return apiDisponible.value =
          r.success &&
          r.statusCode == 200 &&
          r.data is Map &&
          (r.data as Map)['status'] == 'ok' &&
          (r.data as Map)['database'] == 'connected';
    } catch (_) {
      return apiDisponible.value = false;
    }
  }

  /// Comparte el ciclo activo para impedir dos envíos concurrentes desde botones/eventos.
  Future<void> sincronizar() =>
      _ciclo ??= _drenar().whenComplete(() => _ciclo = null);

  /// Solicita envío posterior al commit y actualización local de UI, sin esperar red ni duplicar ciclos.
  void solicitarAutomatica() {
    if (_ciclo != null) _otroIntento = true;
    unawaited(sincronizar());
  }

  /// Procesa una nueva acción llegada durante el ciclo anterior sin polling ni reintentos infinitos.
  Future<void> _drenar() async {
    do {
      _otroIntento = false;
      await _ejecutar();
    } while (_otroIntento &&
        puedeIntentarEnvio &&
        estado.value != EstadoSincronizacionActual.error &&
        estado.value != EstadoSincronizacionActual.reautenticacion);
  }

  /// Valida sesión antes y después de cada espera; un cambio de cuenta corta el ciclo.
  Future<void> _ejecutar() async {
    final usuario = _sesion.usuario?.id;
    final token = _sesion.token;
    if (usuario == null || token == null) {
      estado.value = EstadoSincronizacionActual.reautenticacion;
      return;
    }
    if (_conectividad.sinRed) {
      estado.value = EstadoSincronizacionActual.offline;
      return;
    }
    estado.value = EstadoSincronizacionActual.sincronizando;
    bool vigente() => _sesion.usuario?.id == usuario && _sesion.token == token;
    try {
      if (!await comprobarDisponibilidadApi()) {
        estado.value = EstadoSincronizacionActual.error;
        return;
      }
      if (!vigente()) return;
      if (tickets == null || sucursales == null || evidencias == null) {
        estado.value = EstadoSincronizacionActual.error;
        return;
      }
      OperacionesSqlite.exigir(await _cola.recuperar(usuario));
      final pendientes = OperacionesSqlite.exigir(
        await _cola.obtenerPendientes(usuarioId: usuario),
      );
      for (final p in pendientes) {
        if (!vigente()) return;
        if (p.usuarioId != usuario) continue;
        if (p.recurso != 'tickets' &&
            p.recurso != 'evidencias' &&
            p.recurso != 'eventos' &&
            p.recurso != 'asignaciones' &&
            p.recurso != 'solicitudes') {
          estado.value = EstadoSincronizacionActual.pendientes;
          continue;
        }
        OperacionesSqlite.exigir(await _cola.marcarProcesando(p.id));
        try {
          RespuestaApi r;
          final local = p.payload['id_local'] as int;
          if (p.recurso == 'solicitudes') {
            final repo = RepositorioSolicitudes(tickets!.sql);
            final s = await repo.obtener(local, usuario);
            if (s == null) throw StateError('Solicitud ausente.');
            final t = await tickets!.obtener(
              s['ticket_id_local'] as int,
              usuario,
            );
            if (t?.idRemoto == null ||
                (p.operacion == TipoOperacionLocal.actualizar &&
                    s['id_remoto'] == null)) {
              OperacionesSqlite.exigir(await _cola.devolverPendiente(p.id));
              continue;
            }
            if (p.operacion == TipoOperacionLocal.crear) {
              r = await _api.post(
                RutasApi.solicitarEstado(t!.idRemoto!),
                token: token,
                payload: {
                  'type': s['tipo'],
                  'reason': s['motivo'],
                  'clientRequestId': s['client_request_id'],
                  'createdAt': s['created_at'],
                  'eventClientRequestId': p.payload['eventClientRequestId'],
                },
              );
            } else {
              r = await _api.put(
                RutasApi.revisarSolicitud(s['id_remoto'] as int),
                token: token,
                payload: {
                  'status': p.payload['status'],
                  'reviewedAt': p.payload['reviewedAt'],
                  'decisionClientRequestId':
                      p.payload['decisionClientRequestId'],
                  'finalClientRequestId': p.payload['finalClientRequestId'],
                },
              );
            }
          } else if (p.recurso == 'asignaciones') {
            final t = await tickets!.obtener(local, usuario);
            if (t?.idRemoto == null) {
              OperacionesSqlite.exigir(await _cola.devolverPendiente(p.id));
              continue;
            }
            r = await _api.put(
              RutasApi.asignacion(t!.idRemoto!),
              token: token,
              payload: {'technicianId': p.payload['tecnico_id']},
            );
          } else if (p.recurso == 'tickets') {
            final t = await tickets!.obtener(local, usuario);
            if (t == null) throw StateError('Ticket local ausente.');
            if (p.operacion == TipoOperacionLocal.actualizar &&
                t.idRemoto != null) {
              r = await _api.put(
                '${RutasApi.tickets}/${t.idRemoto}',
                token: token,
                payload: {
                  'title': p.payload['title'] ?? t.titulo,
                  'description': p.payload['description'] ?? t.descripcion,
                  'status': p.payload['status'] ?? t.estado,
                  'scheduledAt': p.payload.containsKey('scheduledAt')
                      ? p.payload['scheduledAt']
                      : t.programado?.toUtc().toIso8601String(),
                },
              );
            } else {
              r = await _api.post(
                RutasApi.tickets,
                token: token,
                payload: t.paraCrear(),
              );
            }
          } else if (p.recurso == 'evidencias') {
            final e = await evidencias!.obtener(local, usuario);
            if (e == null) throw StateError('Evidencia ausente.');
            final t = await tickets!.obtener(
              e['ticket_id_local'] as int,
              usuario,
            );
            if (t?.idRemoto == null) {
              OperacionesSqlite.exigir(await _cola.devolverPendiente(p.id));
              continue;
            }
            r = await _api.post(
              RutasApi.evidencia(t!.idRemoto!),
              token: token,
              payload: {
                'description': e['descripcion'],
                'photoBase64': e['photo_base64'],
                'mime': e['mime'],
                'isInitial': p.payload['initial'] == true,
              },
            );
          } else {
            final e = await RepositorioEventos(
              tickets!.sql,
            ).obtener(local, usuario);
            if (e == null) throw StateError('Evento ausente.');
            final t = await tickets!.obtener(
              e['ticket_id_local'] as int,
              usuario,
            );
            int? evidencia;
            if (e['evidencia_id_local'] != null) {
              final foto = await evidencias!.obtener(
                e['evidencia_id_local'] as int,
                usuario,
              );
              evidencia = foto?['id_remoto'] as int?;
              if (evidencia == null) {
                OperacionesSqlite.exigir(await _cola.devolverPendiente(p.id));
                continue;
              }
            }
            if (t?.idRemoto == null) {
              OperacionesSqlite.exigir(await _cola.devolverPendiente(p.id));
              continue;
            }
            r = await _api.post(
              RutasApi.eventos(t!.idRemoto!),
              token: token,
              payload: {
                'eventType': e['tipo_evento'],
                'description': e['descripcion'],
                'createdAt': e['created_at'],
                'clientRequestId': e['client_request_id'],
                'previousScheduledAt': e['previous_scheduled_at'],
                'scheduledAt': e['scheduled_at'],
                'evidenceId': evidencia,
              },
            );
          }
          if (!r.success || r.data is! Map || (r.data as Map)['id'] is! int) {
            await registrarEstadoProtegido(r.statusCode);
            OperacionesSqlite.exigir(
              await _cola.marcarError(p.id, ErrorSincronizacion.servidor),
            );
            estado.value = r.statusCode == 401
                ? EstadoSincronizacionActual.reautenticacion
                : EstadoSincronizacionActual.error;
            return;
          }
          if (!vigente()) {
            OperacionesSqlite.exigir(await _cola.devolverPendiente(p.id));
            return;
          }
          final remoto = (r.data as Map)['id'] as int;
          if (p.recurso == 'solicitudes') {
            await RepositorioSolicitudes(
              tickets!.sql,
            ).confirmar(local, remoto, usuario, p.id, p.payload);
          } else if (p.recurso == 'tickets' || p.recurso == 'asignaciones') {
            await tickets!.confirmar(local, remoto, usuario, p.id);
          } else if (p.recurso == 'evidencias') {
            await evidencias!.confirmar(local, remoto, usuario, p.id);
          } else {
            await RepositorioEventos(
              tickets!.sql,
            ).confirmar(local, remoto, usuario, p.id);
          }
        } catch (_) {
          await _cola.marcarError(p.id, ErrorSincronizacion.respuesta);
          estado.value = EstadoSincronizacionActual.error;
          return;
        }
      }
      if (!vigente()) return;
      final ramas = await _api.get(RutasApi.sucursales, token: token);
      if (!await _validarDescarga(ramas)) return;
      if (!vigente()) return;
      await sucursales!.guardar(usuario, ramas.data as List);
      final agenda = await _api.get(RutasApi.tickets, token: token);
      if (!await _validarDescarga(agenda)) return;
      if (!vigente()) return;
      final rol = _sesion.usuario?.roleId ?? 2;
      final coordinacion = RepositorioCoordinacion(tickets!.sql);
      if (rol == 1 || rol == 3) {
        final equipo = await _api.get(RutasApi.tecnicos, token: token);
        if (!await _validarDescarga(equipo) || !vigente()) return;
        await coordinacion.guardar(usuario, equipo.data as List);
      }
      final equipo = await coordinacion.listar(usuario);
      await tickets!.descargar(
        usuario,
        agenda.data as List,
        rol: rol,
        tecnicos: equipo.map((t) => t['id'] as int).toSet(),
      );
      final locales = await tickets!.agenda(usuario);
      for (final dato in agenda.data as List) {
        if (!vigente()) return;
        final remoto = dato as Map;
        final local = locales.firstWhereOrNull(
          (t) => t.idRemoto == remoto['id'],
        );
        if (local != null && remoto['evidences'] is List) {
          await evidencias!.descargar(
            local.idLocal,
            usuario,
            remoto['evidences'] as List,
          );
        }
        if (local != null) {
          final eventosRemotos = await _api.get(
            RutasApi.eventos(local.idRemoto!),
            token: token,
          );
          if (!await _validarDescarga(eventosRemotos)) return;
          if (!vigente()) return;
          await RepositorioEventos(
            tickets!.sql,
          ).descargar(local.idLocal, usuario, eventosRemotos.data as List);
        }
      }
      final solicitudes = await _api.get(
        '${RutasApi.solicitudes}?pendingOnly=false',
        token: token,
      );
      if (!await _validarDescarga(solicitudes) || !vigente()) return;
      await RepositorioSolicitudes(
        tickets!.sql,
      ).descargar(usuario, solicitudes.data as List);
      final restantes = OperacionesSqlite.exigir(
        await _cola.obtenerPendientes(usuarioId: usuario),
      );
      estado.value = restantes.isEmpty
          ? EstadoSincronizacionActual.actualizado
          : EstadoSincronizacionActual.pendientes;
    } catch (_) {
      estado.value = EstadoSincronizacionActual.error;
    } finally {
      if (estado.value == EstadoSincronizacionActual.sincronizando) {
        estado.value = _sesion.requiereReautenticacion
            ? EstadoSincronizacionActual.reautenticacion
            : EstadoSincronizacionActual.pendientes;
      }
    }
  }

  /// Convierte respuestas inválidas/401 a estado público sin aparentar una descarga exitosa.
  Future<bool> _validarDescarga(RespuestaApi r) async {
    await registrarEstadoProtegido(r.statusCode);
    if (!r.success || r.data is! List) {
      estado.value = r.statusCode == 401
          ? EstadoSincronizacionActual.reautenticacion
          : EstadoSincronizacionActual.error;
      return false;
    }
    return true;
  }
}
