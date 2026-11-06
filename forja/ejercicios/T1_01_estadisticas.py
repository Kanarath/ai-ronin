"""Ejercicio T1-01 · Estadísticas descriptivas, sin librerías.

Vas a reproducir lo que hace el comando `dataset stats` del Dojo.
Python que practicas: abrir ficheros, listas, diccionarios, bucles y funciones.

Ejecuta los tests desde forja/ejercicios:
    python -m unittest -v test_T1_01_estadisticas
"""


def cargar_csv(ruta):
    """Lee un CSV con cabecera y devuelve una lista de diccionarios, uno por fila.

    Las claves son los nombres de la cabecera y los valores, el TEXTO de cada celda
    (todavía sin convertir a número). Las líneas vacías se ignoran.

    Ejemplo, para un fichero con estas líneas:
        id,dureza_hrc,calidad
        hoja-1,59.7,apta
    devuelve:
        [{"id": "hoja-1", "dureza_hrc": "59.7", "calidad": "apta"}]

    Pistas de Python: open(ruta, encoding="utf-8"), línea.strip(), texto.split(","),
    dict(zip(claves, valores)).
    """
    raise NotImplementedError("Tu turno: implementa cargar_csv")


def columna(filas, nombre):
    """Extrae una columna numérica: lista de floats en el mismo orden que las filas.

    Ejemplo: columna([{"a": "1.5"}, {"a": "2"}], "a") → [1.5, 2.0]
    """
    raise NotImplementedError("Tu turno: implementa columna")


def media(valores):
    """Media aritmética: suma de los valores / número de valores.

    Ejemplo: media([1, 2, 3, 6]) → 3.0
    """
    raise NotImplementedError("Tu turno: implementa media")


def desviacion_tipica(valores):
    """Desviación típica POBLACIONAL: raíz de la media de (x − media)².

    Divide entre n (no entre n−1), igual que el Dojo y que numpy.std por defecto.
    Ejemplo: desviacion_tipica([2, 4, 4, 4, 5, 5, 7, 9]) → 2.0
    Pista: la raíz cuadrada es valor ** 0.5 (o math.sqrt).
    """
    raise NotImplementedError("Tu turno: implementa desviacion_tipica")


def rango(valores):
    """Máximo menos mínimo.

    Ejemplo: rango([3, 10, 7]) → 7
    Reto: hazlo primero con un bucle y después con min() y max().
    """
    raise NotImplementedError("Tu turno: implementa rango")


def recuento(etiquetas):
    """Cuántas veces aparece cada etiqueta. Devuelve un diccionario.

    Ejemplo: recuento(["apta", "defectuosa", "apta"]) → {"apta": 2, "defectuosa": 1}
    """
    raise NotImplementedError("Tu turno: implementa recuento")
