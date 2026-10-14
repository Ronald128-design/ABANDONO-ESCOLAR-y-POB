.a <- commandArgs(FALSE)
.f <- sub("^--file=", "", .a[grep("^--file=", .a)])
proyecto <- if (length(.f)) dirname(dirname(normalizePath(.f))) else getwd()
directorio <- Sys.getenv("DESGRANAMIENTO_DATA", file.path(proyecto, "datos", "bases"))
salida <- file.path(proyecto, "resultados", "analisis-exploratorio")
modo <- get0("modo", ifnotfound = "todo")
args <- commandArgs(TRUE)
if (length(args)) modo <- args[1]
stopifnot(modo %in% c("datos", "m1", "m2", "m3", "todo"))

leer <- function(nombre) {
  ruta <- file.path(directorio, paste0(gsub("_", "-", nombre, fixed = TRUE), ".csv"))
  if (!file.exists(ruta)) stop("Archivo ausente: ", ruta)
  read.csv(ruta, fileEncoding = "UTF-8", check.names = FALSE,
           stringsAsFactors = FALSE, na.strings = "")
}
requerir <- function(paquetes) {
  faltan <- paquetes[!vapply(paquetes, requireNamespace, logical(1), quietly = TRUE)]
  if (length(faltan)) stop("Faltan paquetes: ", paste(faltan, collapse = ", "))
}
guardar <- function(x, nombre) {
  dir.create(salida, recursive = TRUE, showWarnings = FALSE)
  write.csv(x, file.path(salida, paste0(gsub("_", "-", nombre, fixed = TRUE), ".csv")), row.names = FALSE,
            fileEncoding = "UTF-8", na = "")
}
describir <- function(datos, variables) {
  do.call(rbind, lapply(variables, function(v) {
    x <- datos[[v]]
    y <- x[!is.na(x)]
    if (!length(y)) stop("Variable sin observaciones: ", v)
    data.frame(variable = v, n = length(y), faltantes = sum(is.na(x)),
               media = mean(y), de = sd(y), minimo = min(y),
               q1 = unname(quantile(y, .25)), mediana = median(y),
               q3 = unname(quantile(y, .75)), maximo = max(y))
  }))
}
coeficientes <- function(modelo, covarianza) {
  x <- lmtest::coeftest(modelo, vcov. = covarianza)
  data.frame(termino = rownames(x), estimacion = x[, 1], ee = x[, 2],
             estadistico = x[, 3], p = x[, 4], row.names = NULL)
}
guardar_modelo <- function(modelo, datos, nombre) {
  stopifnot(nobs(modelo) == nrow(datos), !anyNA(coef(modelo)))
  guardar(coeficientes(modelo, sandwich::vcovHC(modelo, type = "HC3")),
          paste0(nombre, "_hc3"))
  guardar(as.data.frame(clubSandwich::coef_test(
    modelo, vcov = "CR2", cluster = datos$departamento, test = "Satterthwaite"
  )), paste0(nombre, "_cr2"))
}
m1 <- leer("m1_corte_2022")
m2 <- leer("m2_panel")
m3 <- leer("m3_abandono")
retencion <- leer("m3_retencion")
educacion_inicial <- leer("m3_educacion_inicial")
cruce <- leer("cruce_distritos")
stopifnot(!anyDuplicated(m1$clave_distrito),
          !anyDuplicated(m2[c("clave_distrito", "ano")]),
          !anyDuplicated(m3[c("clave_distrito", "ciclo", "zona", "sector", "sexo", "periodo")]),
          !anyNA(m3$clave_distrito), all(m3$clave_distrito %in% m1$clave_distrito),
          !anyNA(m3$abandono), all(m3$abandono >= 0 & m3$abandono <= 1),
          all(m1$desgranamiento >= 0 & m1$desgranamiento <= 1),
          all(m2$desgranamiento >= 0 & m2$desgranamiento <= 1))
for (d in list(m1, m2)) {
  stopifnot(all(d$matricula_primer_grado > 0),
            max(abs(d$retencion_g9_g1 - d$matricula_noveno_grado / d$matricula_primer_grado)) <= 5.00001e-6,
            max(abs(d$desgranamiento - pmax(0, 1 - d$retencion_g9_g1))) < 1e-12,
            all(d$privacion_educativa_relativa == as.integer(d$retencion_g9_g1 < d$percentil_25_departamental)))
}
p2022 <- m2[m2$ano == 2022, ]
stopifnot(setequal(p2022$clave_distrito, m1$clave_distrito))
p2022 <- p2022[match(m1$clave_distrito, p2022$clave_distrito), ]
comunes <- intersect(names(m1), names(m2))
stopifnot(isTRUE(all.equal(m1[comunes], p2022[comunes], check.attributes = FALSE)))
conteos <- data.frame(base = c("m1", "m2", "m3", "retencion", "educacion_inicial"),
                      registros = c(nrow(m1), nrow(m2), nrow(m3), nrow(retencion), nrow(educacion_inicial)))
print(conteos)
if (modo != "datos") {
  dir.create(salida, recursive = TRUE, showWarnings = FALSE)
  guardar(conteos, "conteos")
}

if (modo %in% c("m1", "todo")) {
  requerir(c("sandwich", "lmtest", "clubSandwich", "quantreg"))
  nuevas <- c("pobreza_monetaria_ine_2022", "nbi_al_menos_una_2022", "nbi_vivienda_2022",
              "nbi_sanitaria_2022", "nbi_educacion_2022", "nbi_subsistencia_2022")
  contexto <- c("ipm_h_percent", "pobreza", "inasistencia", "sobreedad", "logro_minimo", "trabajo_infantil")
  estructura <- c("proporcion_urbana", "proporcion_oficial", "numero_de_instituciones")
  guardar(describir(m1, c("desgranamiento", "retencion_g9_g1", estructura, contexto, nuevas)), "m1_descriptivos")
  asociaciones <- do.call(rbind, lapply(nuevas, function(v) {
    d <- m1[complete.cases(m1[c(v, "desgranamiento")]), ]
    t <- cor.test(d[[v]], d$desgranamiento, method = "spearman", exact = FALSE)
    data.frame(variable = v, n = nrow(d), rho = unname(t$estimate), p = t$p.value)
  }))
  asociaciones$p_holm <- p.adjust(asociaciones$p, method = "holm")
  guardar(asociaciones, "m1_asociaciones_ine")
  formulas <- list(
    estructura = reformulate(estructura, "desgranamiento"),
    monetaria = reformulate(c(estructura, nuevas[1]), "desgranamiento"),
    nbi = reformulate(c(estructura, nuevas[2]), "desgranamiento"),
    conjunta = reformulate(c(estructura, nuevas[1:2]), "desgranamiento"),
    material = reformulate(c(estructura, nuevas[c(1, 3, 4)]), "desgranamiento")
  )
  m1_ine <- m1[complete.cases(m1[unique(c("desgranamiento", estructura, nuevas))]), ]
  modelos <- lapply(formulas, function(f) lm(f, data = m1_ine, na.action = na.fail))
  for (n in names(modelos)) guardar_modelo(modelos[[n]], m1_ine, paste0("m1_", n))
  guardar(do.call(rbind, lapply(names(modelos), function(n) {
    s <- summary(modelos[[n]])
    data.frame(modelo = n, n = nobs(modelos[[n]]), r2 = s$r.squared, r2_ajustado = s$adj.r.squared)
  })), "m1_ajuste")
  principal <- modelos$conjunta
  guardar(data.frame(clave_distrito = m1_ine$clave_distrito, ajustado = fitted(principal),
                     residuo = residuals(principal), leverage = hatvalues(principal),
                     cook = cooks.distance(principal)), "m1_diagnosticos")
  m1_frac <- glm(formulas$conjunta, data = m1_ine, family = quasibinomial("logit"), na.action = na.fail)
  guardar(coeficientes(m1_frac, sandwich::vcovCL(m1_frac, cluster = m1_ine$departamento)), "m1_fraccional")
  set.seed(20260928)
  m1_cuantiles <- quantreg::rq(formulas$conjunta, tau = c(.10, .25, .50, .75, .90), data = m1_ine)
  cuantiles_resumen <- summary(m1_cuantiles, se = "boot", R = 1999,
                              cluster = as.integer(factor(m1_ine$departamento)))
  guardar(do.call(rbind, lapply(cuantiles_resumen, function(x) {
    z <- x$coefficients
    data.frame(tau = x$tau, termino = rownames(z), estimacion = z[, 1], ee = z[, 2],
               estadistico = z[, 3], p = z[, 4], row.names = NULL)
  })), "m1_cuantiles")
  m1_cc <- m1[complete.cases(m1[c("desgranamiento", estructura, contexto)]), ]
  modelo_contexto <- lm(reformulate(c(estructura, contexto), "desgranamiento"), data = m1_cc, na.action = na.fail)
  guardar_modelo(modelo_contexto, m1_cc, "m1_contexto_departamental")
  comparable <- lm(formulas$conjunta, data = m1_cc, na.action = na.fail)
  guardar_modelo(comparable, m1_cc, "m1_ine_muestra_contexto")
  no_sintetica <- m1_ine[m1_ine$pobreza_estimacion_sintetica == "No", ]
  modelo_no_sintetica <- lm(formulas$conjunta, data = no_sintetica, na.action = na.fail)
  guardar_modelo(modelo_no_sintetica, no_sintetica, "m1_sin_estimaciones_sinteticas")
  lodo <- do.call(rbind, lapply(unique(m1_ine$departamento), function(d) {
    modelo <- lm(formulas$conjunta, data = m1_ine[m1_ine$departamento != d, ], na.action = na.fail)
    data.frame(departamento_excluido = d, termino = names(coef(modelo)), estimacion = unname(coef(modelo)))
  }))
  guardar(lodo, "m1_exclusion_departamento")
  saveRDS(list(modelos = modelos, fraccional = m1_frac, cuantiles = m1_cuantiles,
               contexto = modelo_contexto, muestra_comparable = comparable,
               sin_sinteticas = modelo_no_sintetica), file.path(salida, "m1-modelos.rds"))
}

if (modo %in% c("m2", "todo")) {
  requerir("fixest")
  olas <- do.call(rbind, lapply(split(m2, m2$ano), function(d) {
    x <- d$desgranamiento
    mu <- mean(x)
    gini <- if (mu == 0) 0 else sum(abs(outer(x, x, "-"))) / (2 * length(x)^2 * mu)
    positivos <- x[x > 0]
    theil <- if (mu == 0) 0 else sum((positivos / mu) * log(positivos / mu)) / length(x)
    data.frame(ano = d$ano[1], n = nrow(d), media = mu, mediana = median(x),
               de = sd(x), gini = gini, theil = theil, media_retencion = mean(d$retencion_g9_g1))
  }))
  guardar(olas, "m2_olas")
  f <- desgranamiento ~ i(ano) + proporcion_urbana + proporcion_oficial + numero_de_instituciones | clave_distrito
  modelo_fe <- fixest::feols(f, data = m2, cluster = ~clave_distrito)
  m2_balanceado <- m2[m2$panel_completo_cinco_olas == "Sí", ]
  modelo_fe_balanceado <- fixest::feols(f, data = m2_balanceado, cluster = ~clave_distrito)
  for (v in c("proporcion_urbana", "proporcion_oficial", "numero_de_instituciones")) {
    m2[[paste0(v, "_media")]] <- ave(m2[[v]], m2$clave_distrito, FUN = mean)
    m2[[paste0(v, "_within")]] <- m2[[v]] - m2[[paste0(v, "_media")]]
  }
  modelo_wb <- fixest::feols(
    desgranamiento ~ i(ano) + proporcion_urbana_within + proporcion_oficial_within +
      numero_de_instituciones_within + proporcion_urbana_media + proporcion_oficial_media +
      numero_de_instituciones_media, data = m2, cluster = ~clave_distrito)
  modelos_panel <- list(fe = modelo_fe, fe_balanceado = modelo_fe_balanceado, within_between = modelo_wb)
  for (n in names(modelos_panel)) {
    z <- as.data.frame(fixest::coeftable(modelos_panel[[n]]))
    z$termino <- rownames(z)
    guardar(z, paste0("m2_", n))
  }
  saveRDS(modelos_panel, file.path(salida, "m2-modelos.rds"))
}

if (modo %in% c("m3", "todo")) {
  requerir(c("sandwich", "lmtest", "geepack", "fixest"))
  for (v in c("periodo", "ciclo", "sexo", "zona", "sector")) m3[[v]] <- factor(m3[[v]])
  m3$estrato <- interaction(m3$clave_distrito, m3$ciclo, m3$zona, m3$sector, m3$sexo, drop = TRUE)
  m3 <- m3[order(m3$estrato, m3$periodo), ]
  rownames(m3) <- NULL
  m3$ola <- as.integer(m3$periodo)
  f <- abandono ~ periodo * ciclo + sexo + zona + sector
  modelo_frac <- glm(f, data = m3, family = quasibinomial("logit"), na.action = na.fail)
  guardar(coeficientes(modelo_frac, sandwich::vcovCL(modelo_frac, cluster = m3$clave_distrito, type = "HC1")), "m3_fraccional")
  modelo_gee <- geepack::geeglm(f, id = estrato, waves = ola, data = m3,
                               family = binomial("logit"), corstr = "exchangeable", std.err = "san.se")
  stopifnot(modelo_gee$geese$error == 0)
  z <- as.data.frame(summary(modelo_gee)$coefficients)
  z$termino <- rownames(z)
  guardar(z, "m3_gee_estrato")
  modelo_fe <- fixest::feols(abandono ~ i(periodo, ciclo) + sexo + zona + sector | clave_distrito,
                             data = m3, cluster = ~clave_distrito)
  z <- as.data.frame(fixest::coeftable(modelo_fe)); z$termino <- rownames(z)
  guardar(z, "m3_fe_lineal")
  indices <- match(m3$clave_distrito, m1$clave_distrito)
  stopifnot(!anyNA(indices))
  nuevas <- c("pobreza_monetaria_ine_2022", "nbi_al_menos_una_2022", "pobreza_estimacion_sintetica")
  m3_con_2022 <- cbind(m3, m1[indices, nuevas])
  stopifnot(nrow(m3_con_2022) == nrow(m3))
  contemporaneo <- m3_con_2022[m3_con_2022$periodo == "2022-2023", ]
  modelo_contexto <- glm(abandono ~ ciclo + sexo + zona + sector + pobreza_monetaria_ine_2022 +
                          nbi_al_menos_una_2022, data = contemporaneo,
                        family = quasibinomial("logit"), na.action = na.fail)
  guardar(coeficientes(modelo_contexto, sandwich::vcovCL(modelo_contexto,
             cluster = contemporaneo$clave_distrito)), "m3_contexto_2022_2023")
  resumenes <- do.call(rbind, lapply(c("periodo", "ciclo", "sexo", "zona", "sector"), function(v) {
    do.call(rbind, lapply(split(m3, m3[[v]]), function(d) {
      data.frame(dimension = v, categoria = as.character(d[[v]][1]), n = nrow(d),
                 media_no_ponderada = mean(d$abandono), mediana = median(d$abandono),
                 de = sd(d$abandono), ceros = sum(d$abandono == 0), unos = sum(d$abandono == 1))
    }))
  }))
  guardar(resumenes, "m3_descriptivos")
  agregado <- aggregate(abandono ~ clave_distrito + periodo, m3, mean)
  names(agregado)[3] <- "abandono_medio_no_ponderado"
  guardar(agregado, "m3_medias_distritales")
  guardar(describir(retencion, "valor_de_retencion"), "m3_retencion_descriptivos")
  guardar(describir(educacion_inicial, "deficit_de_educacion_inicial"), "m3_inicial_descriptivos")
  saveRDS(list(fraccional = modelo_frac, gee = modelo_gee, fe_lineal = modelo_fe,
               contexto = modelo_contexto), file.path(salida, "m3-modelos.rds"))
}
if (modo != "datos") capture.output(sessionInfo(), file = file.path(salida, "sesion-R.txt"))
