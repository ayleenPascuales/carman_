-- Esquema TiDB compatible con MySQL para las rutas implementadas. Solo bases vacías.
CREATE TABLE persona (
  idPersona INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  documento VARCHAR(50) NOT NULL UNIQUE,
  nombre VARCHAR(100) NOT NULL,
  apellido VARCHAR(100) NOT NULL,
  email VARCHAR(100) NOT NULL UNIQUE,
  usuario VARCHAR(50) NOT NULL UNIQUE,
  contrasenaHash VARCHAR(255) NOT NULL,
  uidFirebase VARCHAR(128) NOT NULL UNIQUE,
  telefono VARCHAR(20) NOT NULL,
  fechaNacimiento DATE NOT NULL,
  ciudad VARCHAR(50) NOT NULL,
  direccion VARCHAR(200) NOT NULL,
  fotoPerfil VARCHAR(500) NOT NULL,
  estado VARCHAR(50) NOT NULL DEFAULT 'Activo',
  emailVerificado TINYINT(1) NOT NULL DEFAULT 0,
  fechaHoraRegistro DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  ultimaActividad DATETIME DEFAULT NULL,
  INDEX idx_persona_actividad (estado, ultimaActividad)
);

CREATE TABLE licencia (
  idLicencia INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  idPersona INT NOT NULL UNIQUE,
  numeroDocumento VARCHAR(50) NOT NULL UNIQUE,
  fechaExpiracion DATE NOT NULL,
  estado VARCHAR(50) NOT NULL DEFAULT 'Vigente',
  tipoLicencia VARCHAR(50) NOT NULL,
  fotoLicencia VARCHAR(500) NOT NULL,
  FOREIGN KEY (idPersona) REFERENCES persona(idPersona)
);

CREATE TABLE cliente (
  idCliente INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  idPersona INT NOT NULL UNIQUE,
  FOREIGN KEY (idPersona) REFERENCES persona(idPersona)
);

CREATE TABLE conductor (
  idConductor INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  idPersona INT NOT NULL UNIQUE,
  calificacion DECIMAL(5,2) DEFAULT NULL,
  disponibilidad TINYINT(1) NOT NULL DEFAULT 0,
  FOREIGN KEY (idPersona) REFERENCES persona(idPersona)
);

CREATE TABLE propietario (
  idPropietario INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  idPersona INT NOT NULL UNIQUE,
  FOREIGN KEY (idPersona) REFERENCES persona(idPersona)
);

CREATE TABLE administrador (
  idAdministrador INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  idPersona INT NOT NULL UNIQUE,
  estado VARCHAR(50) NOT NULL DEFAULT 'Activo',
  FOREIGN KEY (idPersona) REFERENCES persona(idPersona)
);

CREATE TABLE punto_autorizado (
  idPunto INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(100) NOT NULL,
  ciudad VARCHAR(50) NOT NULL,
  direccion VARCHAR(200) NOT NULL,
  latitud DECIMAL(10,6) DEFAULT NULL,
  longitud DECIMAL(10,6) DEFAULT NULL,
  activo TINYINT(1) NOT NULL DEFAULT 1
);

CREATE TABLE vehiculo (
  idVehiculo INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  idPropietario INT NOT NULL,
  placa VARCHAR(20) NOT NULL UNIQUE,
  marca VARCHAR(50) NOT NULL,
  modelo VARCHAR(50) NOT NULL,
  anio INT NOT NULL,
  capacidad INT NOT NULL,
  tipoVehiculo VARCHAR(50) NOT NULL,
  estado VARCHAR(50) NOT NULL DEFAULT 'revision_pendiente',
  idPuntoRecogida INT NOT NULL,
  idPuntoEntrega INT NOT NULL,
  fotos JSON NOT NULL,
  descripcion VARCHAR(200) DEFAULT NULL,
  tarjetaPropiedad VARCHAR(500) NOT NULL,
  estado_solicitud_revision VARCHAR(50) DEFAULT NULL,
  motivo_solicitud_revision VARCHAR(200) DEFAULT NULL,
  motivo_rechazo_revision VARCHAR(200) DEFAULT NULL,
  fecha_aprobacion_revision DATETIME DEFAULT NULL,
  INDEX idx_vehiculo_propietario (idPropietario),
  INDEX idx_vehiculo_recogida (idPuntoRecogida),
  INDEX idx_vehiculo_entrega (idPuntoEntrega),
  FOREIGN KEY (idPropietario) REFERENCES propietario(idPropietario),
  FOREIGN KEY (idPuntoRecogida) REFERENCES punto_autorizado(idPunto),
  FOREIGN KEY (idPuntoEntrega) REFERENCES punto_autorizado(idPunto)
);

CREATE TABLE estado_tecnico_vehiculo (
  idEstado INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
  idVehiculo INT NOT NULL,
  kilometraje DECIMAL(10,2) DEFAULT NULL,
  estadoMotor VARCHAR(50) DEFAULT NULL,
  estadoFrenos VARCHAR(50) DEFAULT NULL,
  estadoLlantas VARCHAR(50) DEFAULT NULL,
  estadoBateria VARCHAR(50) DEFAULT NULL,
  observaciones VARCHAR(200) DEFAULT NULL,
  necesitaMantenimiento TINYINT(1) NOT NULL,
  nombreTecnico VARCHAR(100) DEFAULT NULL,
  documentoTecnico VARCHAR(20) DEFAULT NULL,
  fechaHoraRegistro DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  INDEX idx_estado_tecnico_vehiculo (idVehiculo),
  FOREIGN KEY (idVehiculo) REFERENCES vehiculo(idVehiculo)
);
