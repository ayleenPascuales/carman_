-- Independiente de las tablas de negocio: también se puede revisar y ejecutar
-- manualmente SOLO esta sentencia en una base existente (sin db:migrate).
CREATE TABLE phone_verification (
  phoneHash BINARY(32) NOT NULL PRIMARY KEY,
  idPersona BIGINT NOT NULL,
  codigoHash BINARY(32) DEFAULT NULL,
  expiresAt DATETIME NOT NULL DEFAULT '1970-01-01 00:00:00',
  attempts TINYINT UNSIGNED NOT NULL DEFAULT 0,
  windowStart DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  sendCount TINYINT UNSIGNED NOT NULL DEFAULT 0,
  lastSentAt DATETIME DEFAULT NULL,
  INDEX idx_phone_verification_persona (idPersona)
);
