modo <- "datos"
.a <- commandArgs(FALSE)
.f <- sub("^--file=", "", .a[grep("^--file=", .a)])
source(file.path(if (length(.f)) dirname(normalizePath(.f)) else file.path(getwd(), "codigo"), "analisis-exploratorio.R"))
