CREATE DATABASE PRESTAMOS

GO


--///////////////////////////////////TABLAS///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
USE[PRESTAMOS]

GO

CREATE TABLE TB_DISPOSITIVO
(
    ID INT NOT NULL IDENTITY(1,1),
    SERIAL VARCHAR(255) NULL,
    NOMBREDISP VARCHAR(255) NOT NULL,
	MODELO VARCHAR(255) NULL,
    CONSTRAINT PK_DISPOSITIVO PRIMARY KEY(ID)
)

CREATE TABLE TB_USUARIO
(
    ID INT NOT NULL IDENTITY(1,1),
    NOMBREUSER VARCHAR(255) NOT NULL,
	APELLIDO VARCHAR(255) NOT NULL,
    LEGAJO INT NULL,
    CONSTRAINT PK_USUARIO PRIMARY KEY(ID)
)

CREATE TABLE TB_USER_IT
(
	ID INT NOT NULL IDENTITY(1,1),
	NOMBREUSERIT Nvarchar (150) NOT NULL,
	USUARIO nvarchar(150) NOT NULL, --El usuario va a ser su mail
	CLAVE nvarchar(150) NOT NULL,
	PERFIL int NOT NULL,
	ESTADO bit NOT NULL,
	VERIFICADO bit NOT NULL,
	FOMULARIODEINICIO NVARCHAR(255) NULL
	CONSTRAINT PK_USUARIOS PRIMARY KEY(ID)
)

CREATE TABLE TB_PERFILES(
	ID INT NOT NULL,
	PERFIL nvarchar(50) NOT NULL,
	FOMULARIODEINICIO nvarchar(250) NOT NULL,
	ESTADO bit NOT NULL,
 CONSTRAINT PK_PERFILES PRIMARY KEY (ID) 
)

CREATE TABLE TB_PERFIL_OPCIONES(
	IDPERFIL int NOT NULL,
	IDOPCIONES int NOT NULL,
	ESTADO int NOT NULL,
	CONSTRAINT PK_PERFIL_OPCIONES PRIMARY KEY (IDPERFIL)
)


CREATE TABLE TB_OPCIONESMENU(
	IDOPCION int NOT NULL,
	OPCION nvarchar (250) NOT NULL,
	ESTADO bit NOT NULL,
 CONSTRAINT PK_OPCIONESMENU PRIMARY KEY(IDOPCION) 
 )

CREATE TABLE TB_PRESTAMO
(
    ID INT NOT NULL IDENTITY(1,1),
    FECPRESTAMO DATE NOT NULL,
    FECDEVOLUCIONESTIMADA DATE NOT NULL,
    FECDEVOLUCION DATE NULL,
    CS_USERITCREO INT NOT NULL,
	CS_USERITFIN INT NOT NULL,
    CS_USUARIO INT NOT NULL,
    CS_DISPOSITIVO INT NOT NULL,
    CONSTRAINT PK_PRESTAMO PRIMARY KEY(ID),
	CONSTRAINT FK_USERITCREO_PRESTAMO FOREIGN KEY (CS_USERITCREO) REFERENCES TB_USER_IT (ID),
	CONSTRAINT FK_USERITFIN_PRESTAMO FOREIGN KEY (CS_USERITFIN) REFERENCES TB_USER_IT (ID),
    CONSTRAINT FK_USUARIO_PRESTAMO FOREIGN KEY (CS_USUARIO) REFERENCES TB_USUARIO(ID),
    CONSTRAINT FK_DISPOSITIVO_PRESTAMO FOREIGN KEY (CS_DISPOSITIVO) REFERENCES TB_DISPOSITIVO(ID),
)





--////////////////////STORED PROCEDURES///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

USE [PRESTAMOS]
GO



--////////////////Explicacion funcion/////////////
-- Recibo usuario y clave, devuelvo el id de usuario, el nombre de usuario, el nombre de la persona, la clave, el tipo de perfil, el estado y el formulario de inicio
CREATE PROCEDURE SP_LOGIN

@USUARIO NVARCHAR(255),
@CLAVE NVARCHAR (255)

AS
BEGIN
SELECT
IT.ID,
IT.USUARIO,
IT.NOMBREUSERIT,
IT.CLAVE,
IT.PERFIL,
IT.ESTADO,
IT.FOMULARIODEINICIO
FROM TB_USER_IT IT
INNER JOIN TB_PERFILES PERF ON PERF.ID=IT.PERFIL 
WHERE IT.USUARIO=@USUARIO AND IT.CLAVE=@CLAVE AND IT.VERIFICADO = 1
END
GO



--////////////////Explicacion funcion/////////////
-- Recibo el nombre de usuario (mail) le genero una clave aleatoria y se la envio a su mail 
CREATE PROCEDURE SP_RECUPERAR_CONTRASENA

@MAIL NVARCHAR(255)

AS
BEGIN
---- Creo clave random
DECLARE @RANDOM INT;
DECLARE @SUP INT;
DECLARE @INF INT
SET @INF = 10000000 ---- el valor mas bajo
SET @SUP = 99999999 ---- el valor mas alto
SET @RANDOM = ROUND(((@SUP - @INF -1) * RAND() + @INF), 0)

--Guardo nueva clave en la tabla
UPDATE TB_USER_IT
SET CLAVE = (CONVERT(varchar(255), @RANDOM))
WHERE USUARIO = @MAIL

--Envio la clave al mail en caso de que exista
IF @@ROWCOUNT>0 -- Si se encontro (y modifico) la clave en el update anterior, entonces envio el mail al usuario que quiso recuperar su clave
	BEGIN
		DECLARE @BODY VARCHAR(MAX)
		SET @BODY='<html><body><b style="font-family: Arial;">Su nueva contraseña del sistema es: </> '
		set @BODY= @BODY + (SELECT CLAVE FROM TB_USER_IT WHERE USUARIO = @MAIL) 
		set @BODY= @BODY + '</Body></html>'

		declare @DESTINATARIOS VARCHAR (255)
		set @DESTINATARIOS = (SELECT USUARIO FROM TB_USER_IT WHERE USUARIO= @MAIL)
		exec [Correos].[dbo].[CSP_BSAR_SEND_DBMAIL] @DESTINATARIOS,'','','Recuperacion clave', @BODY --Ejecuto el stored procedure que envia el mail
		
		select('Se envio un mail a su casilla para recuperar la clave') -- Si todo salio bien, envio mail de respuesta
	END
IF @@ROWCOUNT=0 -- Si no se encontro (ni modifico) la clave en el update anterior, respondo con un error
	BEGIN
		select('Error al recuperar su clave, verifique su nombre de usuario/mail')
	END

END
GO




--////////////////Explicacion funcion/////////////
CREATE PROCEDURE SP_CAMBIAR_CLAVE

@IDUSERIT,
@CLAVENUEVA
AS BEGIN

	UPDATE TB_USERIT
	SET CLAVE = @CLAVENUEVA
	WHERE ID = @IDUSERIT

END



--////////////////Explicacion funcion/////////////
-- Recibo datos del prestamo, creo el prestamo y en caso de que existan el usuario al que se presto copio su id  para no agregarlo y en caso de que el dispositivo exista copio su id para no agregarlo
CREATE PROCEDURE SP_NUEVO_PRESTAMO
--MODIFICAR Y AGREGAR USUARIOS QUE NO TIENEN LEGAJO COMO PROVEEDORES
@IDUSERIT NVARCHAR(150),
@SERIAL NVARCHAR(150),
@NOMBREDISPOSITIVO NVARCHAR(150),
@MODELO NVARCHAR(255),
@LEGAJO INT,
@NOMBREUSER VARCHAR(255),
@APELLIDO VARCHAR(255),
@FECPRESTAMO DATE,
@FECDEVOLESTIMADA DATE

AS
BEGIN
-- Busco el dispositivo para actualizarlo
UPDATE TB_DISPOSITIVO SET NOMBREDISP =@NOMBREDISPOSITIVO, MODELO=@MODELO WHERE SERIAL = @SERIAL AND SERIAL IS NOT NULL
IF @@ROWCOUNT=0 --si no encontro el activo por su serial (y el serial no es nulo)
BEGIN
	IF @SERIAL IS NULL-- -si el dispositivo no se encontro, pero tiene serial, lo busco por serial(en caso de que el nombre haya sido mal ingresado por el usuario)
	BEGIN
		UPDATE TB_DISPOSITIVO SET SERIAL= @SERIAL, MODELO=@MODELO WHERE NOMBREDISP=@NOMBREDISPOSITIVO
        IF @@ROWCOUNT=0 --si la herramienta no se encuentra por su nombre
        BEGIN
            INSERT INTO TB_DISPOSITIVO (SERIAL, MODELO, NOMBREDISP) VALUES (@SERIAL, @MODELO, @NOMBREDISPOSITIVO)-- inserto el nuevo dispositivo    
        END
    END
 END


-- Busco al usuario, si existe, le hace un update, al hacer este update el rowcount cuenta 1 o mas modificacion de filas.
UPDATE TB_USUARIO SET NOMBREUSER=@NOMBREUSER, APELLIDO=@APELLIDO WHERE LEGAJO = @LEGAJO AND LEGAJO IS NOT NULL--AGREGAR RESTRICCION EN WEB SI LA PERSONA NO TIENE LEGAJO
IF @@ROWCOUNT=0--Si no hubo modificacion(si el usuario no existe), entonces lo agrego
BEGIN
	INSERT INTO TB_USUARIO (NOMBREUSER, APELLIDO, LEGAJO) VALUES (@NOMBREUSER, @APELLIDO, @LEGAJO)
END
 --para insertar las claves foraneas busco las coincidencias con los datos de los dos inserts anteriores
INSERT INTO TB_PRESTAMO (FECPRESTAMO, FECDEVOLUCIONESTIMADA, CS_USERITCREO, CS_USUARIO, CS_DISPOSITIVO)
VALUES (GETDATE(), @FECDEVOLESTIMADA, @IDUSERIT, (SELECT ID FROM TB_USUARIO WHERE NOMBREUSER=@NOMBREUSER AND LEGAJO=@LEGAJO),(SELECT ID FROM TB_DISPOSITIVO WHERE SERIAL=@SERIAL AND NOMBREDISP=@NOMBREDISPOSITIVO) )
END
GO



--////////////////Explicacion funcion/////////////
-- Traigo los datos de los prestamos en los que no se ingreso la fecha de devolucion (no se devolvieron) ordenados por los prestamos mas viejos
CREATE PROCEDURE SP_PRESTAMOS_ACTIVOS
AS
BEGIN

SELECT	DISP.SERIAL, DISP.NOMBREDISP, IT.NOMBREUSERITCREO, PREST.FECPRESTAMO, PREST.FECDEVOLUCIONESTIMADA, US.NOMBREUSER, US.APELLIDO, US.LEGAJO
		
FROM TB_PRESTAMO PREST 
JOIN TB_DISPOSITIVO DISP ON DISP.ID=PREST.CS_DISPOSITIVO
JOIN TB_USUARIO US ON US.ID= PREST.CS_USUARIO
JOIN TB_USER_IT IT ON IT.ID = PREST.CS_USERITCREO
WHERE PREST.FECDEVOLUCION IS NULL
ORDER BY PREST.FECPRESTAMO ASC

END
GO



--////////////////Explicacion funcion/////////////
-- Ingreso fecha devolucion en el prestamo en cuestion para darlo por finalizado
CREATE PROCEDURE SP_FINALIZAR_PRESTAMO

@IDPRESTAMO INT,
@IDUSERITFIN INT

AS
BEGIN

UPDATE TB_PRESTAMO
SET CS_USERITFIN = @IDUSERITFIN
SET FECDEVOLUCION = GETDATE()
WHERE ID = @IDPRESTAMO

END
GO



--////////////////Explicacion funcion/////////////
-- Traigo todos los prestamos hechos desde el mas actual al mas viejo junto con los actuales activos
CREATE PROCEDURE SP_HISTORIAL_PRESTAMOS
AS
BEGIN

SELECT DISP.SERIAL, DISP.NOMBREDISP,IT.NOMBREUSERITCREO, IT.NOMBREUSERITFIN, PREST.FECPRESTAMO, PREST.FECDEVOLUCIONESTIMADA, US.NOMBREUSER,US.APELLIDO, US.LEGAJO
FROM TB_PRESTAMO PREST 
JOIN TB_DISPOSITIVO DISP ON DISP.ID=PREST.CS_DISPOSITIVO
JOIN TB_USUARIO US ON US.ID=PREST.CS_USUARIO
JOIN TB_USER_IT IT ON IT.ID = PREST.CS_USERIT
ORDER BY PREST.FECPRESTAMO DESC

END
GO



--////////////////Explicacion funcion/////////////
-- Traigo todos los prestamos hechos desde el mas actual al mas viejo filtrado por user it
CREATE PROCEDURE SP_FILTRO_USER_IT

@IDUSERIT INT

AS
BEGIN

SELECT DISP.SERIAL, DISP.NOMBREDISP, IT.NOMBREUSERITCREO, IT.NOMBREUSERITFIN, PREST.FECPRESTAMO, PREST.FECDEVOLUCIONESTIMADA, US.NOMBREUSER, US.APELLIDO, US.LEGAJO
FROM TB_PRESTAMO PREST 
JOIN TB_DISPOSITIVO DISP ON DISP.ID=PREST.CS_DISPOSITIVO
JOIN TB_USUARIO US ON US.ID=PREST.CS_USUARIO
JOIN TB_USER_IT IT ON IT.ID = PREST.CS_USERIT
WHERE IT.ID = @IDUSERIT
ORDER BY PREST.FECPRESTAMO DESC

END
GO



--////////////////Explicacion funcion/////////////
-- Traigo todos los prestamos hechos desde el mas actual al mas viejo filtrado por usuario
CREATE PROCEDURE SP_FILTRO_USUARIO

@IDUSUARIO INT

AS
BEGIN

SELECT DISP.SERIAL, DISP.NOMBREDISP, IT.NOMBREUSERITCREO, IT.NOMBREUSERITFIN, PREST.FECPRESTAMO, PREST.FECDEVOLUCIONESTIMADA, US.NOMBREUSER, US.APELLIDO, US.LEGAJO
FROM TB_PRESTAMO PREST 
JOIN TB_DISPOSITIVO DISP ON DISP.ID=PREST.CS_DISPOSITIVO
JOIN TB_USUARIO US ON US.ID=PREST.CS_USUARIO
JOIN TB_USER_IT IT ON IT.ID = PREST.CS_USERIT
WHERE US.ID = @IDUSUARIO
ORDER BY PREST.FECPRESTAMO DESC

END
GO



--////////////////Explicacion funcion/////////////
-- Traigo todos los prestamos hechos desde el mas actual al mas viejo filtrado por dispositivo
CREATE PROCEDURE SP_FILTRO_DISPOSITIVO

@SERIAL INT

AS
BEGIN

SELECT DISP.SERIAL, DISP.NOMBREDISP, IT.NOMBREUSERITCREO, IT.NOMBREUSERITFIN, PREST.FECPRESTAMO, PREST.FECDEVOLUCIONESTIMADA, US.NOMBREUSER, US.APELLIDO, US.LEGAJO
FROM TB_PRESTAMO PREST 
JOIN TB_DISPOSITIVO DISP ON DISP.ID=PREST.CS_DISPOSITIVO
JOIN TB_USUARIO US ON US.ID=PREST.CS_USUARIO
JOIN TB_USER_IT IT ON IT.ID = PREST.CS_USERIT
WHERE DISP.SERIAL = @SERIAL AND DISP.SERIAL IS NOT NULL --Siempre y cuando se envie un serial valido para filtrar, se va a traer la info del mismo
ORDER BY PREST.FECPRESTAMO DESC

END
GO

--////////////////Explicacion funcion/////////////
-- Cuento la cantidad de prestamos vencidos a la fecha. Cuento la cantidad de id  que su fecha de devolucion estimada sea mayor a la fecha actual
CREATE PROCEDURE SP_JOB_ALERTAS_VENCIMIENTOS


AS
BEGIN

DECLARE @CANT INT

SET @CANT = (SELECT COUNT(ID)
FROM TB_PRESTAMO PREST 
WHERE FECDEVOLUCION IS NOT NUlL
 AND FECDEVOLUCIONESTIMADA > GETDATE())

IF @CANT > 0
BEGIN
DECLARE @BODY VARCHAR(MAX)
		SET @BODY='<html><body><b style="font-family: Arial;">Hay </> '
		set @BODY= @BODY + @CANT
		set @BODY= @BODY + '<b style="font-family: Arial;"> prestamos vencidos. Por favor contactese con el usuario para la devolucion o finalicelos.</> </Body></html>'

		declare @DESTINATARIOS VARCHAR (255)
		set @DESTINATARIOS = 'ArtimeNahuel@proveedor.la-bridgestone.com'
		exec [Correos].[dbo].[CSP_BSAR_SEND_DBMAIL] @DESTINATARIOS,'','','Prestamos vencidos', @BODY --Ejecuto el stored procedure que envia el mail
END

END
GO


----////////////////Explicacion funcion/////////////
----  validar usuario recibiendo el mail
--CREATE PROCEDURE SP_VALIDACION_USER

--@MAIL NVARCHAR(255)

--AS
--BEGIN

--DECLARE @FORM VARCHAR(255)


--SET @FORM='RUTA DEL FORMULARIO/'

--IF @CANT > 0
--BEGIN
--DECLARE @BODY VARCHAR(MAX)
--		SET @BODY='<html><body><b style="font-family: Arial;">Active su usuario ingresando al siguiente link: </> '
--		set @BODY= @BODY + @FORM
--        set @BODY= @BODY + '/'
--        set @BODY= @BODY + (SELECT ID FROM TB_USER_IT WHERE USUARIO = @MAIL)
--		set @BODY= @BODY + '<b style="font-family: Arial;"> No podra ingresar a su cuenta hasta que verifique su cuenta.</> </Body></html>'

--		declare @DESTINATARIOS VARCHAR (255)
--		set @DESTINATARIOS = @MAIL
--		exec [Correos].[dbo].[CSP_BSAR_SEND_DBMAIL] @DESTINATARIOS,'','','Verificacion usuario', @BODY --Ejecuto el stored procedure que envia el mail
--END

--END
--GO

