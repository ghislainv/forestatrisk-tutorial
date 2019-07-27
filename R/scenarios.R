#!/usr/bin/Rscript

# ==============================================================================
# author          :Ghislain Vieilledent
# email           :ghislain.vieilledent@cirad.fr, ghislainv@gmail.com
# web             :https://ghislainv.github.io
# license         :GPLv3
# ==============================================================================

# Library
library(dplyr)
library(readr)
library(ggplot2)

# Data with forest cover and population from 1990 to 2017
# see: http://dx.doi.org/10.18167/DVN1/AUBRRC
df_par_forpop <- read_csv("data/scenarios/forpop.txt")
df_par <- df_par %>% filter(Year >= 2000)

# Time-interval
int <- df_par$Year[-c(1)]-df_par$Year[-length(df_par$Year)]

## Deforestation
area_defor <- df_par$For[-length(df_par$For)]-df_par$For[-c(1)]
ann_defor <- area_defor/int

# New columns
df_par$D <- c(ann_defor,NA)
# Coefficients from Barnes model
df_par$lX <- log(df_par$D) - 0.607 * log(df_par$For) - 0.493 * log(df_par$Pop)

# Weighted regression to estimate beta0
# weight equals to period length (in yr)
mod <- lm(lX~1,data=df_par, weights=c(int,NA))
beta0 <- mod$coefficients[1] # -5.941
sigma2 <- var(mod$residuals) # 0.219

# Function to predict annual deforestation
D.func <- function (Forest, Pop, par) {
	beta0 <- par[1]
	beta1 <- par[2]
	beta2 <- par[3]
	V <- par[4]
	D <- exp(beta0+(V/2)+beta1*log(Forest)+beta2*log(Pop))
	return (D)
}

# Projecting deforestation and forest cover
df_un <- read_csv("data/scenarios/un_pop.txt")
Year <- c(2017, seq(2020, 2100, by=5))
niter <- length(Year)-1
For <- For_np <- c(df_par$For[df_par$Year==2017], rep(NA,17))
Pop <- c(df_par$Pop[df_par$Year==2017], df_un$Pop[15:31])
D <- D_np <- rep(NA, length(Year))
par <- c(beta0, 0.607, 0.493, sigma2)
for (i in 1:niter) {
	D[i] <- D.func(For[i], Pop[i], par)
	D_np[i] <- D.func(For[i], Pop[1], par) # constant pop
	interval <- ifelse(Year[i]==2017, 3, 5)
	D_int <- D[i]*interval
	D_int_np <- D_np[i]*interval
	For[i+1] <- For[i]-D_int
	For_np[i+1] <- For_np[i]-D_int_np
}
D[niter+1] <- D.func(For[niter+1], Pop[niter+1], par)
D_np[niter+1] <- D.func(For[niter+1], Pop[1], par)
df_forest <- tibble(Year, For, Pop, For_np, D, D_np)
write_csv(df_forest, "output/for_proj.csv")

# ====================================
# Plots
# ====================================

# Plot demography
df_pop_2017 <- df_par %>% filter(Year==2017) %>% select(Year, Pop)
df_un <- dplyr::bind_rows(df_un,df_pop_2017)
pl_demo <- ggplot(data=df_un, aes(Year, Pop/1000)) + 
	geom_line() +
	geom_vline(xintercept=2017, linetype="dashed") + 
	ylab(label="Population (million)") +
	theme(text=element_text(size=20))
ggsave("output/demography.png", pl_demo, width=8, height=5, dpi="retina")

# Plot deforestation
# Weihgted mean deforestation on 2000-2017
for_2000_2017 <- c(9879, 9673, 9320, 8770, 8446)
wt <- c(5, 5, 5, 2)
sum_wt <- sum(wt)
defor_2000_2017 <- (for_2000_2017-c(for_2000_2017[-1], NA)) / c(5, 5, 5, 2, NA)
wt_mean_defor <- weighted.mean(defor_2000_2017[-5], wt/sum_wt)
wt_sd_defor <- sqrt(sum(wt/sum_wt * (defor_2000_2017[-5] - wt_mean_defor)^2))
df_defor_2000_2017 <- data.frame(Year=2008.5, D=wt_mean_defor)
pl_defor <- ggplot(data=df_forest, aes(Year, D)) + 
	geom_line() +
	geom_vline(xintercept=2017, linetype="dashed") + 
	geom_point(data=df_defor_2000_2017, size=2) +
	# geom_errorbar(data=df_defor_2000_2017, aes(ymin=D-wt_sd_defor, ymax=D+wt_sd_defor)) +
	ylab(label="Deforestation (Kha/yr)") +
	theme(text=element_text(size=20))
ggsave("output/deforestation.png", pl_defor, width=8, height=5, dpi="retina")

# Plot forest cover change
forest_2000_2017 <- df_par_forpop %>% filter(Year>=2000)
pl_forest <- ggplot(data=df_forest, aes(Year, For/1000)) + 
	geom_line() +
	geom_vline(xintercept=2017, linetype="dashed") + 
	geom_point(data=forest_2000_2017, size=2) +
	ylab(label="Forest cover (Mha)") +
	theme(text=element_text(size=20))
ggsave("output/forest_cover_change.png", pl_forest, width=8, height=5, dpi="retina") 
# Copy plots
f <- c("output/demography.png", "output/deforestation.png", "output/forest_cover_change.png")
file.copy(from=f, to="manuscript/figures/", overwrite=TRUE)

# Table of forest cover change
For_S1 <- c(rep(NA,4), 8446-c(0,8,33,58,83)*84)
df_fcc <- df_forest %>% select(Year, Pop, For) %>%
	filter(Year %in% c(2017,2025,2050,2075,2100)) %>%
	bind_rows(df_par_forpop %>% filter(!(Year %in% c(1990,2017)))) %>%
	arrange(Year) %>%
	mutate(F_S0=For, F_S1=For_S1) %>%
	mutate(For=ifelse(Year > 2017, NA, For)) %>%
	mutate(F_S0=ifelse(Year < 2017, NA, F_S0)) %>%
	rename(F_Obs=For)
write_csv(df_fcc, "output/df_fcc.csv")
file.copy(from="output/df_fcc.csv", to="manuscript/tables/", overwrite=TRUE)
	


