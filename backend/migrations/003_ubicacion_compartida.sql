-- Migración optativa y aditiva. NO ejecutar db:migrate ni reaplicar 001/002
-- sobre carmandb. Revisar/aplicar solo mediante un cambio controlado de DBA.
-- Una fila por persona y reserva; NO se guardan trayectorias ni histórico.
CREATE TABLE IF NOT EXISTS ubicacion_compartida (
  idReserva INT NOT NULL,
  idPersona INT NOT NULL,
  latitud DECIMAL(10,6) NOT NULL,
  longitud DECIMAL(10,6) NOT NULL,
  compartidaEn DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (idReserva, idPersona),
  KEY idx_ubicacion_caducidad (compartidaEn),
  CONSTRAINT fk_ubicacion_reserva FOREIGN KEY (idReserva) REFERENCES reserva (idReserva),
  CONSTRAINT fk_ubicacion_persona FOREIGN KEY (idPersona) REFERENCES persona (idPersona)
);
