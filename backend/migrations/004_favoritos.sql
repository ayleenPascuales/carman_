-- M6 optativo: aplicar solo en una base de ensayo con migraciones registradas.
-- La identidad siempre se toma del token, nunca de un ID enviado por el cliente.
CREATE TABLE favorito (
  idPersona INT NOT NULL,
  idVehiculo INT NOT NULL,
  fechaHoraRegistro DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (idPersona, idVehiculo),
  INDEX idx_favorito_persona_fecha (idPersona, fechaHoraRegistro, idVehiculo),
  CONSTRAINT fk_favorito_persona FOREIGN KEY (idPersona)
    REFERENCES persona (idPersona) ON DELETE CASCADE,
  CONSTRAINT fk_favorito_vehiculo FOREIGN KEY (idVehiculo)
    REFERENCES vehiculo (idVehiculo) ON DELETE CASCADE
);
