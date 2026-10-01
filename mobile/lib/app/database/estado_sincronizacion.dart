/// Centraliza estados persistidos de la cola para no dispersar strings mágicos.
/// Su nombre se serializa en SQLite; cualquier renombre requerirá una migración.
enum EstadoSincronizacion { pendiente, procesando, sincronizado, error }
