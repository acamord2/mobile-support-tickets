import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:tikets/app/database/conexion_sqlite.dart';
import 'package:tikets/app/database/operaciones_sqlite.dart';
import 'package:tikets/app/database/repositorio_cola.dart';
import 'package:tikets/app/database/repositorio_tickets.dart';
import 'package:tikets/app/database/repositorio_sucursales.dart';
import 'package:tikets/app/database/repositorio_evidencias.dart';
import 'package:tikets/app/database/repositorio_sesion_local.dart';
import 'package:tikets/app/network/cliente_api.dart';
import 'package:tikets/app/network/conexion.dart';
import 'package:tikets/app/services/servicio_sesion.dart';
import 'package:tikets/app/services/servicio_conectividad.dart';
import 'package:tikets/app/services/servicio_sincronizacion.dart';
import 'package:tikets/models/sesion_usuario.dart';
import '../soporte/sesion_simulada.dart';

/// Usa SQLite en memoria y HTTP simulado; nunca detiene bases ni modifica datos del dispositivo.
void main() {
  sqfliteFfiInit();
  for (final caeDuranteEnvio in [false, true]) {
    test('Descarga en solo consultas y conserva pendientes; caída durante envío=$caeDuranteEnvio', () async {
      final local=ConexionSqlite(fabrica:databaseFactoryFfi,ruta:inMemoryDatabasePath);addTearDown(local.cerrar);
      final sql=OperacionesSqlite(local), cola=RepositorioCola(OperacionesSqlite(local));
      final tickets=RepositorioTickets(sql);
      final sesion=ServicioSesion(RepositorioSesionLocal(sql,TokenSimulado()));
      await sesion.establecer(SesionUsuario.fromJson({
        'token':'prueba.${base64Url.encode(utf8.encode(jsonEncode({'exp':DateTime.now().add(const Duration(hours:1)).millisecondsSinceEpoch~/1000})))}.firma',
        'user':{'id':1,'username':'prueba','name':'Prueba','roleId':2,'role':'Técnico'}
      }));
      final id=await tickets.crear(usuario:1,sucursal:10,titulo:'Cambio local',descripcion:'Conservar',programado:null);
      var envios=0,descargas=0;
      final api=Conexion(ClienteApi(client:MockClient((req) async {
        if(req.url.path=='/api/health/disponibilidad')return http.Response(jsonEncode({'lectura':true,'escritura':caeDuranteEnvio,'modo':caeDuranteEnvio?'completo':'solo_consultas'}),200);
        if(req.method!='GET'){envios++;return http.Response('{"title":"Solo consultas"}',503);}
        descargas++;
        return http.Response('[]',200,headers:{'x-modo':'solo-consultas'});
      })));addTearDown(api.close);
      final red=ServicioConectividad(consultar:()async=>[ConnectivityResult.wifi],cambios:const Stream.empty());await red.refrescar();
      final sync=ServicioSincronizacion(red,api,cola,sesion,tickets:tickets,sucursales:RepositorioSucursales(sql),evidencias:RepositorioEvidencias(sql));
      await sync.sincronizar();
      expect(envios,caeDuranteEnvio?1:0);expect(descargas,greaterThanOrEqualTo(3));
      expect(sync.estado.value,EstadoSincronizacionActual.soloConsultas);expect(sync.puedeIntentarEnvio,isFalse);
      final guardado=await tickets.obtener(id,1);expect(guardado!.titulo,'Cambio local');expect(guardado.idRemoto,isNull);expect(guardado.syncStatus,'pending');
      expect(OperacionesSqlite.exigir(await cola.obtenerPendientes(usuarioId:1)),isNotEmpty);
    });
  }
}
