-- Complementa 001_initial en bases de ensayo nuevas. No modifica producción.
-- El orden preserva las dependencias de claves foráneas antes de 003.
ALTER TABLE vehiculo ADD COLUMN precioPorDia DECIMAL(10,2) DEFAULT NULL;

CREATE TABLE metodo_pago (
  idMetodoPago INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(50) NOT NULL UNIQUE,
  proveedor VARCHAR(100) NOT NULL,
  descripcion VARCHAR(200),
  activo TINYINT(1) DEFAULT 1
);

CREATE TABLE documento (
  idDocumento INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  nombreArchivo VARCHAR(255) NOT NULL,
  tipoDocumento VARCHAR(50) NOT NULL,
  contenido LONGBLOB NOT NULL,
  fechaCreacion DATETIME DEFAULT CURRENT_TIMESTAMP,
  tablaOrigen VARCHAR(100),
  idOrigen INT
);

CREATE TABLE telemetria (
  idTelemetria INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  idVehiculo INT NOT NULL,
  latitud DECIMAL(10,6),
  longitud DECIMAL(10,6),
  velocidad DECIMAL(10,2),
  timestampRegistro DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (idVehiculo) REFERENCES vehiculo(idVehiculo)
);

CREATE TABLE reserva (
  idReserva INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  idCliente INT NOT NULL,
  idVehiculo INT NOT NULL,
  idConductor INT,
  fechaHoraReserva DATETIME DEFAULT CURRENT_TIMESTAMP,
  fechaInicioServicio DATE NOT NULL,
  horaInicioServicio TIME NOT NULL,
  fechaFinServicio DATE NOT NULL,
  horaFinServicio TIME NOT NULL,
  estado VARCHAR(50) NOT NULL
    CHECK (estado IN ('Pendiente', 'Confirmada', 'Rechazada', 'Finalizada', 'Cancelada', 'EnCurso')),
  precioEstimado DECIMAL(10,2),
  idPuntoEntrega INT,
  idPuntoRecogida INT,
  estadoRespuestaConductor VARCHAR(20),
  conductoresRechazados JSON,
  decisionSinConductor VARCHAR(20),
  INDEX idx_reserva_cliente (idCliente),
  INDEX idx_reserva_vehiculo_fechas (idVehiculo, fechaInicioServicio, fechaFinServicio),
  INDEX idx_reserva_conductor (idConductor),
  FOREIGN KEY (idCliente) REFERENCES cliente(idCliente),
  FOREIGN KEY (idVehiculo) REFERENCES vehiculo(idVehiculo),
  FOREIGN KEY (idConductor) REFERENCES conductor(idConductor),
  FOREIGN KEY (idPuntoEntrega) REFERENCES punto_autorizado(idPunto),
  FOREIGN KEY (idPuntoRecogida) REFERENCES punto_autorizado(idPunto)
);

CREATE TABLE ruta (
  idRuta INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  idReserva INT NOT NULL,
  origen VARCHAR(100) NOT NULL,
  destino VARCHAR(100) NOT NULL,
  distancia DECIMAL(10,2),
  duracion INT,
  fechaHoraRuta DATETIME DEFAULT CURRENT_TIMESTAMP,
  origenLon DECIMAL(10,6),
  origenLat DECIMAL(10,6),
  destinoLon DECIMAL(10,6),
  destinoLat DECIMAL(10,6),
  proveedorRuta VARCHAR(255),
  fechaHoraCalculo DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (idReserva) REFERENCES reserva(idReserva)
);

CREATE TABLE contrato_alquiler (
  idContratoAlquiler INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  idReserva INT NOT NULL UNIQUE,
  idCliente INT NOT NULL,
  idVehiculo INT NOT NULL,
  idPropietario INT NOT NULL,
  idConductor INT,
  fechaInicio DATE NOT NULL,
  horaInicio TIME NOT NULL,
  fechaFin DATE NOT NULL,
  horaFin TIME NOT NULL,
  lugarRecogida VARCHAR(200) NOT NULL,
  lugarEntrega VARCHAR(200) NOT NULL,
  condiciones VARCHAR(500),
  estado VARCHAR(50) NOT NULL
    CHECK (estado IN ('Pendiente_Firma', 'Activo', 'Finalizado', 'Cancelado')),
  precioTotal DECIMAL(10,2) NOT NULL,
  archivoPdf VARCHAR(500),
  firmaCliente VARCHAR(500),
  fechaHoraGeneracion DATETIME DEFAULT CURRENT_TIMESTAMP,
  firmaPropietario VARCHAR(500),
  firmaConductor VARCHAR(500),
  archivoPdfFirmado VARCHAR(500),
  ordenFirmaActual VARCHAR(20) NOT NULL DEFAULT 'Propietario'
    CHECK (ordenFirmaActual IN ('Propietario', 'Conductor', 'Cliente', 'Completado')),
  fechayHoraFirmaPropietario DATETIME,
  fechayHoraFirmaConductor DATETIME,
  fechayHoraFirmaCliente DATETIME,
  FOREIGN KEY (idReserva) REFERENCES reserva(idReserva),
  FOREIGN KEY (idCliente) REFERENCES cliente(idCliente),
  FOREIGN KEY (idVehiculo) REFERENCES vehiculo(idVehiculo),
  FOREIGN KEY (idPropietario) REFERENCES propietario(idPropietario),
  FOREIGN KEY (idConductor) REFERENCES conductor(idConductor)
);

CREATE TABLE orden_de_pago (
  idOrdenPago INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  idReserva INT NOT NULL UNIQUE,
  fechaHoraEmision DATETIME DEFAULT CURRENT_TIMESTAMP,
  total DECIMAL(10,2) NOT NULL CHECK (total >= 0),
  detalles VARCHAR(255),
  estado VARCHAR(50) NOT NULL DEFAULT 'Activa'
    CHECK (estado IN ('Activa', 'Pagada', 'Anulada')),
  rutaPdf VARCHAR(500),
  FOREIGN KEY (idReserva) REFERENCES reserva(idReserva),
  UNIQUE (idOrdenPago, idReserva)
);

CREATE TABLE pago (
  idPago INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  idReserva INT NOT NULL,
  idOrdenPago INT NOT NULL,
  idMetodoPago INT,
  monto DECIMAL(10,2) NOT NULL,
  fechaHoraPago DATETIME DEFAULT CURRENT_TIMESTAMP,
  referenciaTransaccion VARCHAR(100),
  estado VARCHAR(50) NOT NULL
    CHECK (estado IN ('Pendiente', 'En_proceso', 'Aprobado', 'Rechazado', 'Fallido', 'Cancelado', 'Reembolsado')),
  tipoPago VARCHAR(20) NOT NULL
    CHECK (tipoPago IN ('Anticipo', 'Restante', 'Completo')),
  referenciaWompi VARCHAR(100) UNIQUE,
  idTransaccionWompi VARCHAR(100) UNIQUE,
  INDEX idx_pago_reserva (idReserva),
  FOREIGN KEY (idOrdenPago, idReserva) REFERENCES orden_de_pago(idOrdenPago, idReserva),
  FOREIGN KEY (idMetodoPago) REFERENCES metodo_pago(idMetodoPago)
);

CREATE TABLE notificacion (
  idNotificacion INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  idPersonaDestino INT NOT NULL,
  idReserva INT,
  idPago INT,
  tipo VARCHAR(50) NOT NULL,
  mensaje VARCHAR(500) NOT NULL,
  fechaHoraEnvio DATETIME DEFAULT CURRENT_TIMESTAMP,
  leida TINYINT(1) DEFAULT 0,
  INDEX idx_notificacion_persona (idPersonaDestino, fechaHoraEnvio),
  FOREIGN KEY (idPersonaDestino) REFERENCES persona(idPersona),
  FOREIGN KEY (idReserva) REFERENCES reserva(idReserva),
  FOREIGN KEY (idPago) REFERENCES pago(idPago)
);

CREATE TABLE calificacion (
  idCalificacion INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  idReserva INT NOT NULL,
  idCliente INT NOT NULL,
  idVehiculo INT,
  idConductor INT,
  puntuacion INT NOT NULL CHECK (puntuacion BETWEEN 1 AND 5),
  comentario VARCHAR(500),
  fechaHoraComentario DATETIME DEFAULT CURRENT_TIMESTAMP,
  FOREIGN KEY (idReserva) REFERENCES reserva(idReserva),
  FOREIGN KEY (idCliente) REFERENCES cliente(idCliente),
  FOREIGN KEY (idVehiculo) REFERENCES vehiculo(idVehiculo),
  FOREIGN KEY (idConductor) REFERENCES conductor(idConductor),
  UNIQUE (idReserva, idVehiculo),
  UNIQUE (idReserva, idConductor),
  CHECK ((idVehiculo IS NOT NULL AND idConductor IS NULL)
    OR (idVehiculo IS NULL AND idConductor IS NOT NULL))
);
