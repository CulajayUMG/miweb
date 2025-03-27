USE [GDA0068-OT_Jorge_Culajay];

CREATE TABLE Estado (
    idEstado INT PRIMARY KEY IDENTITY(1,1),
    nombre NVARCHAR(50) NOT NULL 
);



CREATE TABLE CategoriaProductos (
    idCategoria INT PRIMARY KEY IDENTITY(1,1),
    nombre NVARCHAR(100) NOT NULL,
    fechaCreacion DATETIME DEFAULT GETDATE(),
    idEstado INT NOT NULL,
    FOREIGN KEY (idEstado) REFERENCES Estado(idEstado)
);



CREATE TABLE Marca (
    idMarca INT PRIMARY KEY IDENTITY(1,1),
    nombre NVARCHAR(50) NOT NULL
);



CREATE TABLE Accion (
    idAccion INT PRIMARY KEY IDENTITY(1,1),
    nombre NVARCHAR(50) NOT NULL
);

CREATE TABLE Rol (
    idRol INT PRIMARY KEY IDENTITY(1,1),
    nombre NVARCHAR(50) NOT NULL
);

INSERT INTO Rol (nombre)
VALUES ('Administrador'), ('Cliente'), ('Vendedor');

CREATE TABLE Orden (
    idOrden INT PRIMARY KEY IDENTITY(1,1),
    fechaCreacion DATETIME DEFAULT GETDATE(),
    nombreCompleto NVARCHAR(150) NOT NULL,
    direccion NVARCHAR(255) NOT NULL,
    telefono NVARCHAR(15) NULL,
    correo NVARCHAR(100) NULL,
    fechaEntrega DATE NULL,
    total DECIMAL(10,2) NOT NULL,
    idEstado INT NOT NULL,
    FOREIGN KEY (idEstado) REFERENCES Estado(idEstado)
);

CREATE TABLE Clientes (
    idCliente INT PRIMARY KEY IDENTITY(1,1),
    razonSocial NVARCHAR(150) NOT NULL,
    nombreComercial NVARCHAR(150) NOT NULL,
    direccionEntrega NVARCHAR(255) NULL,
    telefono NVARCHAR(15) NULL,
    correo NVARCHAR(100) NULL
);

CREATE TABLE Usuario (
    idUsuario INT PRIMARY KEY IDENTITY(1,1),
    correo NVARCHAR(100) NOT NULL UNIQUE,
    nombre NVARCHAR(100) NOT NULL,
    password NVARCHAR(255) NOT NULL,
    telefono NVARCHAR(15) NULL,
    fechaNacimiento DATE NULL,
    fechaCreacion DATETIME DEFAULT GETDATE(),
    idRol INT NOT NULL,
    idEstado INT NOT NULL,
    idCliente INT NOT NULL,
    FOREIGN KEY (idRol) REFERENCES Rol(idRol),
    FOREIGN KEY (idEstado) REFERENCES Estado(idEstado),
    FOREIGN KEY (idCliente) REFERENCES Clientes(idCliente)
);


CREATE TABLE Producto (
    idProducto INT PRIMARY KEY IDENTITY(1,1),
    nombre NVARCHAR(100) NOT NULL,
    codigo NVARCHAR(50) NOT NULL UNIQUE,
    stock INT NOT NULL,
    precio DECIMAL(10,2) NOT NULL,
    fechaCrea DATETIME DEFAULT GETDATE(),
    foto VARBINARY(MAX),
    idCategoria INT NOT NULL,
    idEstado INT NOT NULL,
    idMarca INT NOT NULL,
    idUsuario INT,
    FOREIGN KEY (idCategoria) REFERENCES CategoriaProductos(idCategoria),
    FOREIGN KEY (idEstado) REFERENCES Estado(idEstado),
    FOREIGN KEY (idMarca) REFERENCES Marca(idMarca),
    FOREIGN KEY (idUsuario) REFERENCES Usuario(idUsuario)
);

CREATE TABLE OrdenDetalles (
    idOrdenDetalles INT PRIMARY KEY IDENTITY(1,1),
    cantidad INT NOT NULL,
    precio DECIMAL(10,2) NOT NULL,
    subtotal DECIMAL(10,2) NULL,
    idProducto INT NOT NULL,
    idOrden INT NOT NULL,
    FOREIGN KEY (idProducto) REFERENCES Producto(idProducto),
    FOREIGN KEY (idOrden) REFERENCES Orden(idOrden)
);




CREATE TABLE Bitacora (
    idBitacora INT PRIMARY KEY IDENTITY(1,1),
    idUsuario INT NOT NULL,
    fechaHora DATETIME DEFAULT GETDATE(),
    idAccion INT NULL,
    descripcion NVARCHAR(MAX) NULL,
    idProducto INT NULL,
    FOREIGN KEY (idUsuario) REFERENCES Usuario(idUsuario),
    FOREIGN KEY (idProducto) REFERENCES Producto(idProducto),
    FOREIGN KEY (idAccion) REFERENCES Accion(idAccion)
);



INSERT INTO Estado (nombre)
VALUES 
('Activo'),
('Inactivo'),
('En Proceso'),
('Suspendido');


SELECT 
    u.idUsuario, 
    u.correo AS UsuarioCorreo, 
    u.nombre AS UsuarioNombre, 
    r.nombre AS Rol, 
    e.nombre AS Estado, 
    c.razonSocial, 
    c.nombreComercial, 
    c.direccionEntrega, 
    c.telefono AS ClienteTelefono, 
    c.correo AS ClienteCorreo
FROM Usuario u
INNER JOIN Rol r ON u.idRol = r.idRol
INNER JOIN Estado e ON u.idEstado = e.idEstado
INNER JOIN Clientes c ON u.idCliente = c.idCliente
ORDER BY u.nombre; -- Agregar un orden lógico para facilitar la lectura
GO

-- Creación del trigger trg_CalcularSubtotal
CREATE TRIGGER trg_CalcularSubtotal
ON OrdenDetalles
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    -- Actualiza el subtotal para las filas insertadas o actualizadas
    UPDATE od
    SET od.subtotal = od.cantidad * od.precio
    FROM OrdenDetalles od
    INNER JOIN inserted i ON od.idOrdenDetalles = i.idOrdenDetalles;
END;
GO

CREATE TRIGGER trg_InsertarBitacora_Producto
ON Producto
AFTER INSERT, UPDATE, DELETE
AS
BEGIN
    DECLARE @accion NVARCHAR(100);
    SET @accion = CASE 
        WHEN EXISTS (SELECT 1 FROM inserted) AND EXISTS (SELECT 1 FROM deleted) THEN 'Actualizar'
        WHEN EXISTS (SELECT 1 FROM inserted) THEN 'Insertar'
        ELSE 'Eliminar'
    END;

    INSERT INTO Bitacora (idUsuario, accion, descripcion, idProducto)
    SELECT 
        (SELECT TOP 1 idUsuario FROM Usuario WHERE idRol = 1), -- Asumiendo que el administrador es quien ejecuta la acción
        @accion,
        CASE 
            WHEN @accion = 'Insertar' THEN 'Producto insertado'
            WHEN @accion = 'Actualizar' THEN 'Producto actualizado'
            ELSE 'Producto eliminado'
        END,
        COALESCE(i.idProducto, d.idProducto)
    FROM inserted i
    FULL OUTER JOIN deleted d ON i.idProducto = d.idProducto;
END;
GO


--- vistas
--Total de Productos activos que tenga en stock mayor a 0
CREATE VIEW Vista_ProductosActivosEnStock AS
SELECT 
    COUNT(*) AS TotalProductosActivos
FROM Producto
WHERE 
    idEstado = (SELECT idEstado FROM Estado WHERE nombre = 'Activo') 
    AND stock > 0;
GO

SELECT * FROM Vista_ProductosActivosEnStock;
GO
--Total de Quetzales en ordenes ingresadas en el mes de Agosto 2024
CREATE VIEW Vista_TotalQuetzalesAgosto2024 AS
SELECT 
    SUM(total) AS TotalQuetzales
FROM Orden
WHERE 
    MONTH(fechaCreacion) = 8 
    AND YEAR(fechaCreacion) = 2024;
GO

SELECT * FROM Vista_TotalQuetzalesAgosto2024;
GO

-- Top 10 de clientes con Mayor consumo de ordenes de todo el histórico
CREATE VIEW Vista_Top10ClientesMayorConsumo AS
SELECT TOP 10
    c.idCliente,
    c.razonSocial,
    c.nombreComercial,
    SUM(o.total) AS TotalConsumo
FROM Clientes c
INNER JOIN Usuario u ON c.idCliente = u.idCliente
INNER JOIN Orden o ON o.idEstado = (SELECT idEstado FROM Estado WHERE nombre = 'Activo') 
    AND u.idUsuario = o.idEstado
GROUP BY 
    c.idCliente, 
    c.razonSocial, 
    c.nombreComercial
ORDER BY 
    TotalConsumo DESC;
GO
SELECT * FROM Vista_ProductosActivosEnStock;
GO

-- Top 10 de productos más vendidos en orden ascendente
CREATE VIEW Vista_Top10ProductosMasVendidos AS
SELECT TOP 10
    p.idProducto,
    p.nombre AS NombreProducto,
    SUM(od.cantidad) AS TotalVendidos
FROM Producto p
INNER JOIN OrdenDetalles od ON p.idProducto = od.idProducto
GROUP BY 
    p.idProducto, 
    p.nombre
ORDER BY 
    TotalVendidos ASC;
GO
SELECT * FROM Vista_Top10ProductosMasVendidos;

SELECT * FROM Accion;
SELECT * FROM Bitacora;
SELECT * FROM CategoriaProductos;
SELECT * FROM Clientes;
SELECT * FROM ESTADO;
SELECT * FROM MARCA;
SELECT * FROM ORDEN;
SELECT * FROM OrdenDetalles;
SELECT * FROM Producto;
SELECT * FROM ROL;
SELECT * FROM Usuario;
GO

CREATE PROCEDURE P_InactivarProducto
    @pIdProducto INT,
    @pIdEstado INT
AS
BEGIN
    SET NOCOUNT ON;

    -- Actualiza el estado de un producto a inactivo
    UPDATE Producto
    SET idEstado = @pIdEstado
    WHERE idProducto = @pIdProducto;
    
    -- Verificación para asegurarse que el producto se ha actualizado
    IF @@ROWCOUNT = 0
    BEGIN
        PRINT 'No se encontró el producto con el id especificado';
    END
    ELSE
    BEGIN
        PRINT 'Producto inactivado correctamente';
    END
END;
GO

-- INSERTAR MODIFICAR EN USUARIO
CREATE PROCEDURE P_GuardarUsuario
    @pOpcion INT,
    @pIdUsuario INT = NULL,
    @pCorreo NVARCHAR(100),
    @pNombre NVARCHAR(100),
    @pPassword NVARCHAR(255),
    @pTelefono NVARCHAR(15) = NULL,
    @pFechaNacimiento DATE = NULL,
    @pIdRol INT,
    @pIdEstado INT,
    @pIdCliente INT
AS
BEGIN
    SET NOCOUNT ON;

    IF @pOpcion = 1
    BEGIN
        -- Inserción de un nuevo usuario
        INSERT INTO Usuario (
            correo, nombre, password, telefono, fechaNacimiento, fechaCreacion, idRol, idEstado, idCliente
        ) VALUES (
            @pCorreo, @pNombre, @pPassword, @pTelefono, @pFechaNacimiento, GETDATE(), @pIdRol, @pIdEstado, @pIdCliente
        );
    END
    ELSE
    BEGIN
        -- Actualización de un usuario existente
        UPDATE Usuario
        SET correo = @pCorreo,
            nombre = @pNombre,
            password = @pPassword,
            telefono = @pTelefono,
            fechaNacimiento = @pFechaNacimiento,
            idRol = @pIdRol,
            idEstado = @pIdEstado,
            idCliente = @pIdCliente
        WHERE idUsuario = @pIdUsuario;
    END
END;
GO

EXEC P_GuardarUsuario
    @pOpcion = 1,
    @pIdUsuario = 5,
    @pCorreo = 'usuario@gmail.com',
    @pNombre = 'Juan Pérez',
    @pPassword = '12345',
    @pTelefono = '12345678',
    @pFechaNacimiento = '1990-05-01',
    @pIdRol = 2,
    @pIdEstado = 1,
    @pIdCliente = 1;

EXEC P_GuardarUsuario
    @pOpcion = 2,
    @pIdUsuario = 5,
    @pCorreo = 'usuario_actualizado@gmail.com',
    @pNombre = 'Juan Pérez Actualizado',
    @pPassword = '67890',
    @pTelefono = '87654321',
    @pFechaNacimiento = '1990-05-01',
    @pIdRol = 3,
    @pIdEstado = 2,
    @pIdCliente = 4;

	go

-- INSERTAR MODIFICAR EN PRODUCTO
CREATE PROCEDURE P_GuardarProducto
    @pOpcion INT,
    @pIdProducto INT = NULL,
    @pNombre NVARCHAR(100),
    @pCodigo NVARCHAR(50),
    @pStock INT,
    @pPrecio DECIMAL(10, 2),
    @pIdCategoria INT,
    @pIdEstado INT,
    @pIdMarca INT,
    @pIdUsuario INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @pOpcion = 1
    BEGIN
        -- Inserción de un nuevo producto
        INSERT INTO Producto (
            nombre, codigo, stock, precio, fechaCrea, idCategoria, idEstado, idMarca, idUsuario
        ) VALUES (
            @pNombre, @pCodigo, @pStock, @pPrecio, GETDATE(), @pIdCategoria, @pIdEstado, @pIdMarca, @pIdUsuario
        );
    END
    ELSE
    BEGIN
        -- Actualización de un producto existente
        UPDATE Producto
        SET nombre = @pNombre,
            codigo = @pCodigo,
            stock = @pStock,
            precio = @pPrecio,
            idCategoria = @pIdCategoria,
            idEstado = @pIdEstado,
            idMarca = @pIdMarca,
            idUsuario = @pIdUsuario
        WHERE idProducto = @pIdProducto;
    END
END;
GO

EXEC P_GuardarProducto
    @pOpcion = 1,
    @pIdProducto = NULL,
    @pNombre = 'Laptop HP',
    @pCodigo = 'LP123',
    @pStock = 50,
    @pPrecio = 6500.00,
    @pIdCategoria = 1,
    @pIdEstado = 1,
    @pIdMarca = 2,
    @pIdUsuario = 5;

EXEC P_GuardarProducto
    @pOpcion = 2,
    @pIdProducto = 10,
    @pNombre = 'Laptop HP Pro',
    @pCodigo = 'LP124',
    @pStock = 45,
    @pPrecio = 7000.00,
    @pIdCategoria = 2,
    @pIdEstado = 1,
    @pIdMarca = 3,
    @pIdUsuario = 6;
	GO

-- INSERTAR MODIFICAR EN ORDEN
CREATE PROCEDURE P_GuardarOrden
    @pOpcion INT,
    @pIdOrden INT = NULL,
    @pNombreCompleto NVARCHAR(150),
    @pDireccion NVARCHAR(255),
    @pTelefono NVARCHAR(15) = NULL,
    @pCorreo NVARCHAR(100) = NULL,
    @pFechaEntrega DATE = NULL,
    @pTotal DECIMAL(10, 2),
    @pIdEstado INT
AS
BEGIN
    SET NOCOUNT ON;

    IF @pOpcion = 1
    BEGIN
        -- Inserción de una nueva orden
        INSERT INTO Orden (
            fechaCreacion, nombreCompleto, direccion, telefono, correo, fechaEntrega, total, idEstado
        ) VALUES (
            GETDATE(), @pNombreCompleto, @pDireccion, @pTelefono, @pCorreo, @pFechaEntrega, @pTotal, @pIdEstado
        );
    END
    ELSE
    BEGIN
        -- Actualización de una orden existente
        UPDATE Orden
        SET nombreCompleto = @pNombreCompleto,
            direccion = @pDireccion,
            telefono = @pTelefono,
            correo = @pCorreo,
            fechaEntrega = @pFechaEntrega,
            total = @pTotal,
            idEstado = @pIdEstado
        WHERE idOrden = @pIdOrden;
    END
END;
GO

EXEC P_GuardarOrden
    @pOpcion = 1,
    @pIdOrden = NULL,
    @pNombreCompleto = 'Carlos Ramírez',
    @pDireccion = 'Avenida Siempre Viva, #123',
    @pTelefono = '12345678',
    @pCorreo = 'carlos@gmail.com',
    @pFechaEntrega = '2024-12-15',
    @pTotal = 1200.50,
    @pIdEstado = 3;

	EXEC P_GuardarOrden
    @pOpcion = 2,
    @pIdOrden = 7,
    @pNombreCompleto = 'Carlos Ramírez Actualizado',
    @pDireccion = 'Avenida Actualizada, #456',
    @pTelefono = '87654321',
    @pCorreo = 'carlos_updated@gmail.com',
    @pFechaEntrega = '2024-12-20',
    @pTotal = 1500.75,
    @pIdEstado = 2;

	GO

-- INSERTAR MODIFICAR EN ORDEN DETALLES
CREATE PROCEDURE P_GuardarOrdenDetalles
    @pOpcion INT,
    @pIdOrdenDetalles INT = NULL,
    @pCantidad INT,
    @pPrecio DECIMAL(10, 2),
    @pIdProducto INT,
    @pIdOrden INT
AS
BEGIN
    SET NOCOUNT ON;

    IF @pOpcion = 1
    BEGIN
        -- Inserción de un nuevo detalle de orden
        INSERT INTO OrdenDetalles (
            cantidad, precio, subtotal, idProducto, idOrden
        ) VALUES (
            @pCantidad, @pPrecio, @pCantidad * @pPrecio, @pIdProducto, @pIdOrden
        );
    END
    ELSE
    BEGIN
        -- Actualización de un detalle de orden existente
        UPDATE OrdenDetalles
        SET cantidad = @pCantidad,
            precio = @pPrecio,
            subtotal = @pCantidad * @pPrecio,
            idProducto = @pIdProducto,
            idOrden = @pIdOrden
        WHERE idOrdenDetalles = @pIdOrdenDetalles;
    END
END;
GO

-- MODIFICAR INSERTAR EN CLIENTES
CREATE PROCEDURE P_GuardarCliente
    @pOpcion INT,
    @pIdCliente INT = NULL,
    @pRazonSocial NVARCHAR(150),
    @pNombreComercial NVARCHAR(150),
    @pDireccionEntrega NVARCHAR(255) = NULL,
    @pTelefono NVARCHAR(15) = NULL,
    @pCorreo NVARCHAR(100) = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @pOpcion = 1
    BEGIN
        -- Inserción de un nuevo cliente
        INSERT INTO Clientes (
            razonSocial, nombreComercial, direccionEntrega, telefono, correo
        ) VALUES (
            @pRazonSocial, @pNombreComercial, @pDireccionEntrega, @pTelefono, @pCorreo
        );
    END
    ELSE
    BEGIN
        -- Actualización de un cliente existente
        UPDATE Clientes
        SET razonSocial = @pRazonSocial,
            nombreComercial = @pNombreComercial,
            direccionEntrega = @pDireccionEntrega,
            telefono = @pTelefono,
            correo = @pCorreo
        WHERE idCliente = @pIdCliente;
    END
END;
GO
EXEC P_GuardarCliente
    @pOpcion = 1, 
    @pIdCliente = NULL,
    @pRazonSocial = 'Distribuidora S.A.',
    @pNombreComercial = 'Distribuidora XYZ',
    @pDireccionEntrega = 'Zona 4, Guatemala',
    @pTelefono = '12345678',
    @pCorreo = 'contacto@xyz.com';

	EXEC P_GuardarCliente
    @pOpcion = 2, 
    @pIdCliente = 7,
    @pRazonSocial = 'Distribuidora S.A. Actualizada',
    @pNombreComercial = 'Distribuidora XYZ Plus',
    @pDireccionEntrega = 'Zona 10, Guatemala',
    @pTelefono = '87654321',
    @pCorreo = 'soporte@xyzplus.com';

	GO

-- MOD CATPRODUCTOS
CREATE PROCEDURE P_GuardarCategoriaProducto
    @pOpcion INT,
    @pIdCategoria INT = NULL,
    @pNombre NVARCHAR(100),
    @pIdEstado INT
AS
BEGIN
    SET NOCOUNT ON;

    IF @pOpcion = 1
    BEGIN
        -- Inserción de una nueva categoría de producto
        INSERT INTO CategoriaProductos (
            nombre, fechaCreacion, idEstado
        ) VALUES (
            @pNombre, GETDATE(), @pIdEstado
        );
    END
    ELSE
    BEGIN
        -- Actualización de una categoría de producto existente
        UPDATE CategoriaProductos
        SET nombre = @pNombre,
            idEstado = @pIdEstado
        WHERE idCategoria = @pIdCategoria;
    END
END;
GO

EXEC P_GuardarCategoriaProducto
    @pOpcion = 1,
    @pIdCategoria = NULL,
    @pNombre = 'Electrónica',
    @pIdEstado = 1;

	EXEC P_GuardarCategoriaProducto
    @pOpcion = 2,
    @pIdCategoria = 3,
    @pNombre = 'Electrónica y Tecnología',
    @pIdEstado = 2;

	GO
-- MOD ROL
CREATE PROCEDURE P_GuardarRol
    @pOpcion INT,
    @pIdRol INT = NULL,
    @pNombre NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    IF @pOpcion = 1
    BEGIN
        -- Inserción de un nuevo rol
        INSERT INTO Rol (
            nombre
        ) VALUES (
            @pNombre
        );
    END
    ELSE
    BEGIN
        -- Actualización de un rol existente
        UPDATE Rol
        SET nombre = @pNombre
        WHERE idRol = @pIdRol;
    END
END;
GO
EXEC P_GuardarRol
    @pOpcion = 1,
    @pIdRol = NULL,
    @pNombre = 'Supervisor';

	EXEC P_GuardarRol
    @pOpcion = 2,
    @pIdRol = 2,
    @pNombre = 'Cliente Premium';
GO

-- MOD ESTADO 
CREATE PROCEDURE P_GuardarEstado
    @pOpcion INT,
    @pIdEstado INT = NULL,
    @pNombre NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    IF @pOpcion = 1
    BEGIN
        -- Inserción de un nuevo estado
        INSERT INTO Estado (
            nombre
        ) VALUES (
            @pNombre
        );
    END
    ELSE
    BEGIN
        -- Actualización de un estado existente
        UPDATE Estado
        SET nombre = @pNombre
        WHERE idEstado = @pIdEstado;
    END
END;
GO
EXEC P_GuardarEstado
    @pOpcion = 1,
    @pIdEstado = NULL,
    @pNombre = 'Pendiente';
EXEC P_GuardarEstado
    @pOpcion = 2,
    @pIdEstado = 4,
    @pNombre = 'Completado';
GO

-- MOD MARCA
CREATE PROCEDURE P_GuardarMarca
    @pOpcion INT,
    @pIdMarca INT = NULL,
    @pNombre NVARCHAR(50)
AS
BEGIN
    SET NOCOUNT ON;

    IF @pOpcion = 1
    BEGIN
        -- Inserción de una nueva marca
        INSERT INTO Marca (
            nombre
        ) VALUES (
            @pNombre
        );
    END
    ELSE
    BEGIN
        -- Actualización de una marca existente
        UPDATE Marca
        SET nombre = @pNombre
        WHERE idMarca = @pIdMarca;
    END
END;
GO
EXEC P_GuardarMarca
    @pOpcion = 1,
    @pIdMarca = NULL,
    @pNombre = 'Samsung';

	EXEC P_GuardarMarca
    @pOpcion = 2,
    @pIdMarca = 3,
    @pNombre = 'Samsung Electronics';

	GO
-- MOD ACCION -- esta aun no la he probado-----
CREATE PROCEDURE P_GuardarAccion
    @pOpcion INT,
    @pIdBitacora INT = NULL,
    @pIdUsuario INT,
    @pAccion NVARCHAR(100),
    @pDescripcion NVARCHAR(MAX) = NULL,
    @pIdProducto INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @pOpcion = 1
    BEGIN
        -- Inserción de una nueva acción en la bitácora
        INSERT INTO Bitacora (
            idUsuario, fechaHora, idaccion, descripcion, idProducto
        ) VALUES (
            @pIdUsuario, GETDATE(), @pAccion, @pDescripcion, @pIdProducto
        );
    END
    ELSE
    BEGIN
        -- Actualización de una acción existente en la bitácora
        UPDATE Bitacora
        SET idUsuario = @pIdUsuario,
            idaccion = @pAccion,
            descripcion = @pDescripcion,
            idProducto = @pIdProducto
        WHERE idBitacora = @pIdBitacora;
    END
END;
GO
EXEC P_GuardarAccion
    @pOpcion = 1,
    @pIdBitacora = NULL,
    @pIdUsuario = 5,
    @pAccion = 'Creación de Producto',
    @pDescripcion = 'El usuario creó un nuevo producto llamado "Laptop HP"',
    @pIdProducto = 10;
GO



