# -*- coding: utf-8 -*-
"""
Catálogos ficticios pero realistas para la demo de INAVIT (México).

Todo lo que se genera con estos catálogos es SINTÉTICO. Los pesos y factores
(empleo formal, morosidad, salario) son inventados para dar forma a los
tableros de la demo; no representan estadísticas reales.
"""
import itertools

# ---------------------------------------------------------------------------
# Entidades federativas
# (clave INEGI, nombre, código CURP, región, peso empleo formal,
#  factor morosidad, factor salarial, prefijo CP, municipios)
# ---------------------------------------------------------------------------
ENTIDADES = [
    ("01", "Aguascalientes", "AS", "Occidente-Bajío", 1.6, 0.85, 1.00, 20, ["Aguascalientes", "Jesús María", "Calvillo"]),
    ("02", "Baja California", "BC", "Noroeste", 4.0, 1.20, 1.10, 21, ["Tijuana", "Mexicali", "Ensenada", "Tecate"]),
    ("03", "Baja California Sur", "BS", "Noroeste", 1.0, 1.10, 1.05, 23, ["La Paz", "Los Cabos", "Comondú"]),
    ("04", "Campeche", "CC", "Sur-Sureste", 0.8, 1.05, 0.95, 24, ["Campeche", "Carmen", "Champotón"]),
    ("05", "Coahuila", "CL", "Noreste", 3.6, 0.90, 1.05, 25, ["Saltillo", "Torreón", "Monclova", "Piedras Negras"]),
    ("06", "Colima", "CM", "Occidente-Bajío", 0.8, 1.00, 0.95, 28, ["Colima", "Manzanillo", "Tecomán"]),
    ("07", "Chiapas", "CS", "Sur-Sureste", 1.6, 1.10, 0.85, 29, ["Tuxtla Gutiérrez", "Tapachula", "San Cristóbal de las Casas"]),
    ("08", "Chihuahua", "CH", "Noroeste", 3.8, 1.15, 1.00, 31, ["Chihuahua", "Juárez", "Cuauhtémoc", "Delicias"]),
    ("09", "Ciudad de México", "DF", "Centro", 12.0, 0.95, 1.25, 7, ["Iztapalapa", "Gustavo A. Madero", "Coyoacán", "Benito Juárez"]),
    ("10", "Durango", "DG", "Noroeste", 1.4, 0.95, 0.92, 34, ["Durango", "Gómez Palacio", "Lerdo"]),
    ("11", "Guanajuato", "GT", "Occidente-Bajío", 5.0, 0.90, 1.00, 36, ["León", "Irapuato", "Celaya", "Guanajuato"]),
    ("12", "Guerrero", "GR", "Sur-Sureste", 1.2, 1.30, 0.85, 39, ["Acapulco de Juárez", "Chilpancingo", "Iguala"]),
    ("13", "Hidalgo", "HG", "Centro", 1.8, 1.00, 0.92, 42, ["Pachuca de Soto", "Tulancingo", "Tizayuca"]),
    ("14", "Jalisco", "JC", "Occidente-Bajío", 7.5, 1.00, 1.05, 44, ["Guadalajara", "Zapopan", "Tlaquepaque", "Tonalá"]),
    ("15", "México", "MC", "Centro", 9.0, 1.25, 1.00, 50, ["Ecatepec de Morelos", "Naucalpan de Juárez", "Toluca", "Nezahualcóyotl"]),
    ("16", "Michoacán", "MN", "Occidente-Bajío", 2.4, 1.10, 0.90, 58, ["Morelia", "Uruapan", "Zamora", "Lázaro Cárdenas"]),
    ("17", "Morelos", "MS", "Centro", 1.5, 1.05, 0.95, 62, ["Cuernavaca", "Cuautla", "Jiutepec"]),
    ("18", "Nayarit", "NT", "Occidente-Bajío", 1.0, 1.05, 0.95, 63, ["Tepic", "Bahía de Banderas", "Xalisco"]),
    ("19", "Nuevo León", "NL", "Noreste", 8.0, 0.80, 1.20, 64, ["Monterrey", "Apodaca", "San Nicolás de los Garza", "Guadalupe"]),
    ("20", "Oaxaca", "OC", "Sur-Sureste", 1.3, 1.15, 0.85, 68, ["Oaxaca de Juárez", "Salina Cruz", "Juchitán de Zaragoza"]),
    ("21", "Puebla", "PL", "Centro", 3.6, 1.00, 0.95, 72, ["Puebla", "Tehuacán", "San Martín Texmelucan"]),
    ("22", "Querétaro", "QT", "Occidente-Bajío", 2.8, 0.85, 1.10, 76, ["Querétaro", "San Juan del Río", "Corregidora"]),
    ("23", "Quintana Roo", "QR", "Sur-Sureste", 2.0, 1.35, 1.00, 77, ["Benito Juárez", "Solidaridad", "Othón P. Blanco"]),
    ("24", "San Luis Potosí", "SP", "Occidente-Bajío", 2.4, 0.95, 1.00, 78, ["San Luis Potosí", "Soledad de Graciano Sánchez", "Ciudad Valles"]),
    ("25", "Sinaloa", "SL", "Noroeste", 2.2, 1.15, 0.97, 80, ["Culiacán", "Mazatlán", "Ahome"]),
    ("26", "Sonora", "SR", "Noroeste", 3.2, 1.10, 1.03, 83, ["Hermosillo", "Cajeme", "Nogales"]),
    ("27", "Tabasco", "TC", "Sur-Sureste", 1.3, 1.20, 0.95, 86, ["Centro", "Cárdenas", "Comalcalco"]),
    ("28", "Tamaulipas", "TS", "Noreste", 3.0, 1.30, 1.00, 87, ["Reynosa", "Matamoros", "Tampico", "Nuevo Laredo"]),
    ("29", "Tlaxcala", "TL", "Centro", 0.7, 0.95, 0.88, 90, ["Tlaxcala", "Apizaco", "Huamantla"]),
    ("30", "Veracruz", "VZ", "Sur-Sureste", 3.5, 1.15, 0.92, 91, ["Veracruz", "Xalapa", "Coatzacoalcos", "Córdoba"]),
    ("31", "Yucatán", "YN", "Sur-Sureste", 2.2, 0.90, 0.95, 97, ["Mérida", "Kanasín", "Valladolid"]),
    ("32", "Zacatecas", "ZS", "Occidente-Bajío", 0.9, 0.95, 0.90, 98, ["Zacatecas", "Fresnillo", "Guadalupe"]),
]
ENT_BY_CLAVE = {e[0]: e for e in ENTIDADES}

# ---------------------------------------------------------------------------
# Productos de crédito (INAVIT, nombres inventados)
# (id, nombre, tipo, tasa_min, tasa_max, plazos_años, monto_min, monto_max,
#  peso, factor_mora)
# ---------------------------------------------------------------------------
PRODUCTOS = [
    (1, "INAVIT Hogar Tradicional", "ADQUISICION", 5.5, 10.4, [20, 25, 30], 450000, 1650000, 0.45, 1.00),
    (2, "INAVIT Mejora Tu Hogar", "MEJORAMIENTO", 9.0, 10.5, [3, 4, 5], 25000, 95000, 0.25, 1.50),
    (3, "INAVIT Total", "ADQUISICION_COFINANCIADA", 7.0, 10.4, [20, 25, 30], 900000, 2400000, 0.12, 0.80),
    (4, "INAVIT Unidos", "ADQUISICION_CONYUGAL", 5.0, 9.9, [20, 25, 30], 700000, 2000000, 0.10, 0.90),
    (5, "INAVIT Construye", "CONSTRUCCION", 6.5, 10.4, [10, 15, 20], 300000, 900000, 0.08, 1.10),
]

# ---------------------------------------------------------------------------
# Nombres y apellidos
# ---------------------------------------------------------------------------
NOMBRES_H = [
    "José", "Juan", "Luis", "Carlos", "Jorge", "Francisco", "Javier", "Pedro", "Alejandro",
    "Roberto", "Fernando", "Ricardo", "Daniel", "Eduardo", "Manuel", "Raúl", "Sergio",
    "Arturo", "Mario", "Óscar", "Enrique", "Héctor", "Alberto", "Rafael", "Gerardo",
    "Armando", "Ramón", "Víctor", "Jesús", "Antonio", "Salvador", "Gabriel", "Adrián",
    "Julio", "César", "Guillermo", "Rubén", "Hugo", "Ángel", "Iván", "Diego", "Emmanuel",
    "Jonathan", "Miguel", "David", "Erick", "Cristian", "Gustavo", "Ernesto", "Alfredo",
    "José Luis", "José Antonio", "Juan Carlos", "Luis Ángel", "Miguel Ángel", "José Manuel",
    "Juan Pablo", "Carlos Alberto", "Luis Fernando", "José Guadalupe", "Jesús Alberto",
    "José Alfredo", "Juan Manuel", "José Carlos",
]
NOMBRES_M = [
    "María", "Guadalupe", "Juana", "Margarita", "Verónica", "Patricia", "Leticia",
    "Elizabeth", "Rosa", "Alejandra", "Ana", "Laura", "Silvia", "Gabriela", "Claudia",
    "Martha", "Carmen", "Teresa", "Adriana", "Sandra", "Lucía", "Fernanda", "Daniela",
    "Karla", "Mónica", "Yolanda", "Araceli", "Angélica", "Beatriz", "Cecilia", "Dulce",
    "Esperanza", "Gloria", "Irma", "Lourdes", "Norma", "Olivia", "Rocío", "Susana",
    "Valeria", "Ximena", "Paola", "Jessica", "Brenda", "Diana", "Berenice", "Marisol",
    "Itzel", "Miriam", "Liliana", "Karen", "Paulina", "Maribel", "Elena", "Sofía",
    "María Guadalupe", "María del Carmen", "María Elena", "Ana Laura", "María Fernanda",
    "María José", "Ana Karen", "Rosa María", "María de los Ángeles", "Ana María",
    "María Isabel", "María Teresa",
]
APELLIDOS = [
    "García", "Hernández", "Martínez", "López", "González", "Rodríguez", "Pérez", "Sánchez",
    "Ramírez", "Flores", "Gómez", "Cruz", "Morales", "Vázquez", "Reyes", "Jiménez", "Torres",
    "Díaz", "Gutiérrez", "Ruiz", "Mendoza", "Aguilar", "Ortiz", "Moreno", "Castillo",
    "Romero", "Álvarez", "Méndez", "Chávez", "Rivera", "Juárez", "Ramos", "Domínguez",
    "Herrera", "Medina", "Castro", "Vargas", "Guzmán", "Velázquez", "Muñoz", "Rojas",
    "Contreras", "Salazar", "Luna", "Ortega", "Santiago", "Guerrero", "Estrada", "Bautista",
    "Cortés", "Soto", "Sandoval", "Núñez", "Delgado", "Campos", "Vega", "Fuentes",
    "Cárdenas", "Ibarra", "Valdez", "Peña", "Maldonado", "Trejo", "Rangel", "Navarro",
    "Espinoza", "Carrillo", "Lara", "Pineda", "Acosta", "Ávila", "Padilla", "Montes",
    "Cervantes", "Orozco", "Serrano", "Villanueva", "Zúñiga", "Macías", "Mejía", "Robles",
    "Rosales", "Escobar", "Villegas", "Franco", "Arellano", "Cisneros", "Tapia", "Quintero",
    "Benítez", "Montoya", "Solís", "Figueroa", "Miranda", "Camacho", "Lozano", "Barrera",
    "Meza", "Palacios", "Nava", "Esquivel", "Quiroz", "Alvarado", "Durán", "Becerra",
    "Cabrera", "Paredes", "Zavala", "Olvera", "De la Cruz", "De la Rosa", "De León",
]

# ---------------------------------------------------------------------------
# Patrones: sectores, tipos de razón social, núcleos y formas jurídicas
# ---------------------------------------------------------------------------
SECTORES = [
    # (sector, peso, prefijos posibles)
    ("Manufactura", 0.14, ["Industrias", "Manufacturas", "Grupo Industrial", "Fabricación de"]),
    ("Comercio al por menor", 0.20, ["Comercializadora", "Distribuidora", "Tiendas", "Abarrotes"]),
    ("Construcción", 0.10, ["Constructora", "Desarrollos", "Edificaciones", "Ingeniería y Construcción"]),
    ("Servicios profesionales", 0.10, ["Consultores", "Asesores", "Servicios Profesionales", "Soluciones"]),
    ("Transporte y logística", 0.08, ["Transportes", "Logística", "Fletes", "Autotransportes"]),
    ("Alimentos y restaurantes", 0.09, ["Alimentos", "Restaurantes", "Operadora de Alimentos", "Panificadora"]),
    ("Salud", 0.05, ["Clínica", "Servicios Médicos", "Laboratorios", "Hospital"]),
    ("Educación", 0.04, ["Colegio", "Instituto", "Servicios Educativos", "Academia"]),
    ("Agroindustria", 0.05, ["Agroindustrias", "Agrícola", "Productores", "Empacadora"]),
    ("Tecnologías de la información", 0.04, ["Tecnología", "Sistemas", "Software", "Datos y Cómputo"]),
    ("Servicios financieros", 0.03, ["Financiera", "Servicios Financieros", "Capital", "Sociedad de Ahorro"]),
    ("Hospitalidad y turismo", 0.04, ["Hoteles", "Turismo", "Operadora Turística", "Resorts"]),
    ("Automotriz", 0.03, ["Autopartes", "Automotriz", "Refaccionaria", "Servicio Automotriz"]),
    ("Minería", 0.01, ["Minera", "Explotaciones", "Servicios Mineros"]),
]
NUCLEOS = [
    "Azteca", "Valle Verde", "Sierra Madre", "del Pacífico", "del Norte", "Aurora", "Horizonte",
    "Cumbres", "Mexicana", "del Centro", "Tres Ríos", "Anáhuac", "Tenochtitlan", "Quetzal",
    "Jaguar", "Maya", "Olmeca", "Tolteca", "Huasteca", "Cempasúchil", "San Miguel", "La Esperanza",
    "El Roble", "Los Pinos", "Cerro Grande", "Río Bravo", "Bahía Azul", "Altiplano", "Del Bajío",
    "Nueva Era", "Progreso", "Guadalupana", "Cordillera", "Monarca", "Volcán", "Tezcatlipoca",
    "Zafiro", "Alba", "Meridiano", "Orión", "Atlas", "Delta", "Condor", "Capital", "Unión", "Vanguardia",
]
FORMAS = [
    ("S.A. de C.V.", 0.58), ("S. de R.L. de C.V.", 0.22), ("S.A.P.I. de C.V.", 0.08),
    ("S.C.", 0.05), ("S.A.S.", 0.07),
]

# Despachos de cobranza (HANA)
DESPACHOS = [
    "Despacho Cobranza Norte", "Despacho Cobranza Centro", "Despacho Cobranza Occidente",
    "Despacho Cobranza Sureste", "Cobranza Institucional INAVIT", "Gestoría Hogar Seguro",
    "Recupera Hogar", "Contacto Efectivo",
]
CANALES_PAGO = ["BANCO", "TIENDA_CONVENIENCIA", "PORTAL_WEB", "APP_MOVIL", "CAJERO"]
CANALES_PESOS = [0.40, 0.30, 0.12, 0.12, 0.06]


# ---------------------------------------------------------------------------
# Utilidades de muestreo ponderado
# ---------------------------------------------------------------------------
def cum_weights(weights):
    return list(itertools.accumulate(weights))


def zipf_weights(n, s=0.9, offset=3):
    return [1.0 / ((i + offset) ** s) for i in range(n)]
