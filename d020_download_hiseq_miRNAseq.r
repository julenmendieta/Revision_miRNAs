##d020_download_hiseq_miRNAseq
##2015-04-28 julenmendieta92@gmail.com
## Script completo del análisis de los datos clínicos
##Collecting data from TCGA

## The scripts uses TCGA DCC Web Services to find out all the PROTEIN EXPRESSION data.

## Batch effect is very strong.
## Do just comparisons whiting each disease.

## Find the platform here:
## http://tcga-data.nci.nih.gov/tcgadccws/GetHTML?query=Platform

date ()
Sys.info ()[c("nodename", "user")]
commandArgs ()
rm (list = ls ())
R.version.string ##"R version 3.2.0 (2015-04-16)"
library (RCurl); packageDescription ("RCurl", fields = "Version") #"1.95-4.5"
library (XML); packageDescription ("XML", fields = "Version") #"3.98-1.1"
#help (package = XML)
#help (package = RCurl)

try (source (".job.r")); try (.job)

options (width = 170)
#options (width = 1000)

setwd (file.path (.job$dir$raw, "illuminahiseq_mirnaseq"))

################################################################################
## DOWNLOAD DATA

base <- "https://tcga-data.nci.nih.gov"
#En este punto tenemos illuminahiseq_mirnaseq y illuminaga_mirnaseq, yo he optado por los primeros, ya que tienen mayor calidad
#La pagina con los @names es: https://tcga-data.nci.nih.gov/tcgafiles/ftp_auth/distro_ftpusers/anonymous/tumor/coad/cgcc/
my.url <- "http://tcga-data.nci.nih.gov/tcgadccws/GetXML?query=Archive[Platform[@name=illuminahiseq_mirnaseq]][ArchiveType[@type=Level_3]][@deployStatus=Available][@isLatest=1]"

char <- getURL (my.url)
char

mix <- xmlInternalTreeParse (char)
class (mix)
mix <- xmlChildren (xmlChildren (mix)[["httpQuery"]])[["queryResponse"]]
class (mix)
mix

ns <- getNodeSet (mix, path = "class")
class (ns)
ns

datos <- xmlToDataFrame (ns, stringsAsFactors = FALSE)
dim (datos)
colnames (datos) <- paste0 ("V", 1:ncol (datos))
colnames (datos)[c (1, 3, 7)] <- c("date", "location", "name")
datos[1:3, 1:8]

datos[,"fecha"] <- as.Date (datos[,"date"], "%m-%d-%Y")
datos[,c ("date", "fecha")]

datos[,"url"] <- paste0 (base, datos[,3])
##datos[,"gzfile"] <- basename (datos[,3])
##datos[,"gzfolder"] <- sub (".tar.gz", "", datos[,"gzfile"])

rownames (datos) <- datos[,"name"]

datos[1:3,]
#Hasta aqui hemos tomado los links a una serie de archivos. Si quieres veros copia el link de mu.url cambiando XML por HTML

system.time ({
  for (url in datos[,"url"]) {
    filename <- basename (url)
    download.file (url = url, destfile = filename, method = "curl")
    untar (tarfile = filename, compressed = TRUE)    
  }
})
###
##Todo lo de download data simplemente descarga los archivos comprimidos que podemos obtener desde el data matrix
##Como diferencia se ve que 'CHANGES_DCC.txt' 'DESCRIPTION.txt' 'MANIFEST.txt' 'README_DCC.txt' son algo diferentes a los que vienen desde el array, y están todos juntos dentro de una carpeta

################################################################################

## SOME CHECKS
length (dir (recursive= TRUE))  #Mira el total de ficheros utiles en la carpeta de trabajo y sus subcarpetas

##Con esto cogeriamos también las isoformas
#ficheros <- dir (pattern = "quantification", recursive= TRUE) #Guarda en ficheros todos los ficheros que tengan 'quantification ' en el nombre??
#Con esto la expresión global
ficheros <- dir (pattern = "mirna.quantification", recursive= TRUE)

length (ficheros)  #Mira la longitud de la variable ficheros
ficheros[1:3]  ##No sirve para nada más que ver los primeros 3 ficheros de la lista (te indica la carpeta descargada y cada uno de los archivos dentro)
li <- strsplit (ficheros, ".*/")  #Separa el nombre de los ficheros usando como separador todo el texto hasta '/' Al final queda una especie de código
table (sapply (li, length)) ##OK all 2
barcode <- sapply (li, function (x) x[2])  #Guarda en barcode la zona de la derecha que hay en li (los codigos y el .txt)
#barcode <- sub (".-...-....-..[.].*txt", "", barcode)  #Borra el final sobrante de barcode hasta dejar al final el sample 
barcode <- sub ("[.].*txt", "", barcode)  #Borra el final sobrante hasta dejar el barcode completo
##La separación del barcode en algo más pequeño, hasta llegar al sample, igual es mejor dejarla para después de la búsqueda de duplicados


length (barcode)
folder <- dirname (ficheros)  #Guardamos en folder las carpetas en las que están los ficheros. Las carpetas tienen el nombre que se ha quedado al descomprimir el tar en el que estaban

#Si cambia la base de datos o el tipo de dato esto tendras que cambiarlo
fi <- sub ("bcgsc.ca_", "", ficheros)  #Elimina bcgsc.ca_ de la variable que contiene el nombre de los ficheros y la carpeta en la q están (bcgsc.ca_ está en el inicio del nombre de la carpeta)


li <- strsplit (fi, "\\.") #Separa el contenido de fi (nombre carepta y ficheros) por '\' y '.'
## Lo de arriba creo que esta hecho para windows, en linux seria con \/ --> primera barra indica que se lea la segunda como un caracter y no parte de una orden o algo asi


table (sapply (li, length)) ##OK all the same
#Algunos, como los de READ, tienen hg19 puesto después del barcode, y eso hace que tengan un parametro mas

tag <- sapply (li, function (x) x[1])  #Guarda en tag la primera posicion de li, que es la que hace referencia a la enfermedad, para cada fichero
length (tag)
finfo <- as.data.frame (list (fichero = ficheros, barcode = barcode, folder = folder, tag = tag), stringsAsFactors= FALSE)  #Guarda en esta variable el nombre de la carpeta (q contiene información del nivel) + " " + la referenciaa la enfermedad
class (finfo)  #Mira de que clase es finfo
dim (finfo)
sapply (finfo, class)
table (finfo[,"tag"])  #Crea una tabla en la que acumula la variable tag (info de la enfermedad) de cada fichero. Por tanto muestra cada enfermedad y el numero de ficheros que la estudian en finfo

##Vamos a quitar lo de aqui, porque no tenemos un ID dentro del fichero en estos datos, y esto es para comprobar que el del nombre del fichero y el de dentro son iguales
#finfo[,"uuid.infile"] <- NA
##El bucle sirve para guardar despues de la referencia a la enfermedad una columna con la palabra sample y despues la identidad asociada a ese fichero, el problema es q la Id la obtiene de
##la primera linea del fichero, y en el caso de miRNAseq no hay ID dentro del fichero
# system.time ({  #Mira cuanto tarda en ejecutarse este bucle
#   for (i in 1:nrow (finfo)) {
#     finfo[i, "uuid.infile"] <- readLines (con = finfo[i, "fichero"], n = 1)
#   }
# })
# 
# finfo[,"uuid.infile"] <- sub ("Sample REF\t", "", finfo[,"uuid.infile"])  #La identidad se precedia de 'REF', con esto quitamos esta secuencia de caracteres
# table (finfo[,"uuid"] == finfo[,"uuid.infile"], exclude = NULL) ## OK all the same
# if (any (finfo[,"uuid"] != finfo[,"uuid.infile"])) stop ("uuids do not match")  #Mira que todas las IDs esten bien puestas


summary (finfo)

########################################
## Some duplicated barcodeS ????

#####Tenemos que hacer la comparación de iguales por cada cancer, eso implica generar una tabla en la que el primer nivel son los tags
tags <- unique(tag)

#Miramos que no haya barcodes duplicados en el mismo estudio
for (t in tags) {
  dups <- duplicated (finfo[t,"barcode"])  #Mira los valores de barcode, las IDs, que se repiten
  if (dups == TRUE) stop ("Duplicated barcodes in the same study")
  
  #PROBLEMA1: Que las isoformas tienen el mismo ID que el de las muestras en las que estan los miR a los que se refieren

}


# table (dups)  #Muestra la cantidad de IDs q estan repetidas y la cantidad que no
# duplicados <- finfo[dups, "barcode"]  #Guarda en una tabla los duplicados
# finfo[,"is.dup"] <- finfo[,"barcode"] %in% duplicados  #Añade al final d finfo si esta duplicado 'True' o no 'False'
# table (finfo[,"is.dup"], exclude = NULL)
# table (table (finfo[,"barcode"], exclude = NULL), exclude = NULL)  #Te dice cuantos y cuantas veces están repetidos (el 1 en el 0 veces no se que pinta ahi).
# table (finfo[,"tag"], finfo[,"is.dup"])  #Con esto genera una tabla en la que se muestra por enfermedad los ficheros duplicados
# ##sort by date and SERIAL INDEX
# table (finfo$folder %in% rownames (datos)) ## OK
# 
# finfo[,"fecha"] <- datos[finfo$folder, "fecha"]  #Supongo que esto es para guardar los datos de las fechas al final d finfo o algo asi
# orden <- order (finfo[,"fecha"], finfo[,"is.dup"], finfo[,"barcode"], finfo[,"folder"], decreasing = TRUE)  #Esto para guardar la variable orden
# finfo <- finfo[orden,]  #Esto ya para ordenar por fecha
# finfo[finfo$is.dup,][1:10,]  #Con esto vemos los 10 primeros IDs duplicados
# malos <- finfo[finfo$is.dup,]  #Guardamos en la variable malos los duplicados
# orden <- order (malos[,"barcode"])  
# malos <- malos[orden,]  #Los ordenamos por ID
# table (malos[,"tag"])  #Mostramos en una tabla cuantos hay por enfermedad
# malos[1:10,]  #Aqui se muestra la info de los 10 primeros
# tail (malos)  #El final
# dup <- duplicated (finfo[,"barcode"])  #Guardamos en la variable dup la informacion que dice en booleano si los IDs estan duplicadoos
# table (dup) 
# finfo <- finfo[!dup,]  #Guaradmos en finfo todos los que no están duplicados?
# table (duplicated (finfo[,"barcode"]))
# 
#rownames (finfo) <- finfo[,"barcode"]  #Guardamos como informacion de fila las IDs --> En este script me ha guardado True o False
################################################################################
## READ DATA
#Generamos la tabla de expresión de miRNAs por tags y dentro de los tags el barcode asociado a una muestra y el read_count de cada miRNA
datos.li <- list ()
#En este bucle miramos: 
system.time ({
  for (t in tags) {
    for (i in 1:nrow (finfo)) {  #por cada fila del contenido de finfo
      if (finfo[i, "tag"] == t) {
        datos.li[[t]][[finfo[i, "barcode"]]] <-  #guardar en la lista datos.li, en donde esta la ID ("i" es el numero de cada linea)
          ####Esto se complica, ya que en prot solo hay dos columnas, pero en miR hay diferente numero si son isoformas o el miR########
        ####En el miR nos interesaria la primera, que dice q miR es, y la segunda, que nos dice el numero total de lecturas sin normalizar#####
        ####En la isoforma nos interesaria la primera, que dice q miR es, y la tercera, que nos dice el numero total de lecturas sin normalizar#####
        ####Tomo el total de reads sin normalizar por lo que dice aqui: https://www.biostars.org/p/66612/
        #Antes habia
        #read.table (file = finfo[i, "fichero"], header = TRUE, sep = "\t", quote = "", skip = 1, colClasses = c ("character", "numeric"), row.names = 1)
        #Yo lo cambio a lo siguiente para el modo sin isoformas:
        read.table (file = finfo[i, "fichero"], header = TRUE, sep = "\t", quote = "", skip = 0, colClasses = c ("character", "numeric", rep("NULL", 2)), row.names = 1)
        ##Quitamos skip=1 porque aqui esta solo la cabecera, mientras que en proteinas habia cabecera y otra linea antes con el ID, y le decimos que no mire las 2 ultimas columnas
        #Lo siguiente para el mododo de solo isoformas:
        #read.table (file = finfo[i, "fichero"], header = TRUE, sep = "\t", quote = "", skip = 0, colClasses = c ("character", "NULL", "numeric", rep("NULL", 3)), row.names = 1)
      }  #El contenido del fichero como data frame, teniendo las lineas como casos y las secciones o columnas como variables
    }
  }
})
 

#Me queda ponerle nombre a las columnas? o no hace falta? seria añadir--> col.names=c("miRNA_ID", "read_count")

#Con este bucle ya estamos leyendo los datos de expresión de los ficheros
# length (datos.li)
# table (names (datos.li) == rownames (finfo))  #Comprobamos que names(datos.li) sea igual que la info de rownames
# unique (sapply (datos.li, colnames)) ## OK all columns the same

#########Lo de aqui arriba me da "read_count", miralo a ver en proteinas###################

## MAKE MATRIX
##
#mirar los barcodes de un tag
miR.exp <- list()
for (t in tags) {  
  id.list <- lapply (datos.li[[t]], rownames)  #Guarda en una lista todos los miRNAs que hay analizadas en cada fihcero indicando el ID del mismo.
  ids <- sort (unique (unlist (id.list)))  #Esto sera para guardar en ids el nombre de todos los miRNAs analizadas en orden alfabetico
  ##PROBLEMA: Los miR no se ordenan en orden de valor numerico, sino alfabetico (100 antes que 2), y de cambiarlo, algunos tienen "-" de por medio (hsa-mir-9-2)
  length (ids)
  
  #Generamos para cada caso una matriz con las medidas necesarias
  tabla <- list()
  tabla[[t]] <- matrix (NA, nrow = length (ids), ncol = length (datos.li[[t]]))
  dim (tabla[[t]])
  rownames (tabla[[t]]) <- ids  #nombra cada fila de la matriz tabla según el miR al que hace referencia
  colnames (tabla[[t]]) <- names (datos.li[[t]])  #Aqui a las columnas les da el ID al que hacen referencia, y 
 
  #Ahora guardamos los datos de read_count asociados a cada miR y barcode
  for (barcode in names (datos.li[[t]])) {
    mat <- datos.li[[t]][[barcode]]
    tabla[[t]][,barcode] <- mat[ids,]
  }
  miR.exp[[t]] <- tabla[[t]]
}
##



####PROBLEMA: los valores de read_counts no son equiparables al nivel de expresión de proteinas


#Con este bucle se guarda dentro de la matriz los niveles de expresión de miR al  que se hace referencia con cada ID
#table (colnames (miR.exp) == rownames (finfo))
################################################################################
## ## Some Plots
## table (finfo$tag)
## boxplot (miR.exp[,c(which (finfo$tag == "ACC"), which (finfo$tag == "BLCA"))])
## abline (h = 0, col = "blue")
## boxplot (miR.exp[,c(which (finfo$tag == "KIRP"), which (finfo$tag == "KIRC"))])
## abline (h = 0, col = "blue")
## orden <- order (finfo$tag)
## boxplot (miR.exp[,orden])
## abline (h = 0, col = "blue")
## ran <- sample (colnames (miR.exp), size = 100)
## boxplot (miR.exp[,ran])
## abline (h = 0, col = "blue")
################################################################################
### SAVE
miR.exp.info <- finfo
#table (colnames (miR.exp) == rownames (miR.exp.info))
save (list = c("miR.exp", "miR.exp.info"), file = file.path (.job$dir$proces, "miR_exp.RData")) 

###EXIT
warnings ()
sessionInfo ()
q ("no")
