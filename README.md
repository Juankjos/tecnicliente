# Rutas para Técnico (TecniCliente)

Aplicación móvil desarrollada en **Flutter** para que los técnicos de campo consulten sus rutas de servicio, vean el detalle de cada visita y actualicen el estatus de los trabajos realizados.

## Características principales

- Autenticación de técnicos mediante usuario y contraseña.
- Consulta de rutas asignadas (por día, zona o rango de fechas).
- Visualización de la información del cliente y del servicio a realizar.
- Actualización de estatus del servicio (por ejemplo: pendiente, en curso, realizado, cancelado).
- Integración con un backend en PHP que expone los servicios necesarios para la app.

## Tecnologías

- **Flutter** (Dart)
- **Backend en PHP**:
  - `auth_login.php` – Endpoint de autenticación.
  - `login.php` – Lógica de inicio de sesión del técnico.
  - `get_rutas.php` – Obtiene las rutas/servicios asignados.
  - `get_tecnico.php` – Obtiene información del técnico.
  - `update_status.php` – Actualiza el estatus de un servicio.

---

## Requisitos previos

- Flutter SDK instalado  
- Android Studio o VS Code con extensiones de Flutter/Dart  
- PHP 7+ y servidor web (Apache, Nginx o similar)  
- Base de datos configurada para el backend (MySQL u otra, según tu implementación)

---

## Instalación y ejecución (app Flutter)

1. Clonar este repositorio:

   ```bash
   git clone https://github.com/Juankjos/tecnicliente.git
   cd tecnicliente
