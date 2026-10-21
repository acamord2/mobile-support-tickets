-- Solo lectura; no muestra conninfo ni secretos.
SELECT pg_is_in_recovery(), current_setting('transaction_read_only') AS solo_lectura;
SELECT status,sender_host,sender_port,written_lsn,flushed_lsn,latest_end_lsn,last_msg_receipt_time FROM pg_stat_wal_receiver;
SELECT pg_last_wal_receive_lsn() AS recibido,pg_last_wal_replay_lsn() AS aplicado,
 pg_wal_lsn_diff(pg_last_wal_receive_lsn(),pg_last_wal_replay_lsn()) AS bytes_sin_aplicar,
 pg_last_xact_replay_timestamp() AS ultima_transaccion_aplicada;
-- La antigüedad de la última transacción no mide retraso si el primario está inactivo.
