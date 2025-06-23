library(tidyverse)
# library(ggh4x)
# source("geom_hpline.R")
# library(ggpubr)

files <- list.files("results", full.names = TRUE, pattern = ".csv")
masks <- files[str_detect(files, "mask")]
vectors <- files[!str_detect(files, "mask")]

datm <- tibble(
  file = basename(masks),
  mask = map(masks, data.table::fread)
) %>% 
  separate(file, c("donor", "day", "k", "img"), sep = '_', extra = "drop")  

datv <- tibble(
  file = basename(vectors),
  vectorf = map(vectors, data.table::fread)
) %>% 
  separate(file, c("donor", "day", "k", "img"), sep = '_', extra = "drop")  %>% 
  mutate(img = parse_number(img) %>% as.character())

dat <- full_join(datm, datv)

dat %>% slice (1) %>% unnest(mask)
dat %>% slice (1) %>% unnest(vectorf)

filter_vectors <- function(.mask, .vector) {
  filter(.vector, X %in% .mask$X & Y %in% .mask$Y)
}

# remove samples where either the vectorfield or the mas are missing
missing_vf <- map(dat$vectorf, is.null) %>% unlist() %>% which()
missing_m <- map(dat$mask, is.null) %>% unlist() %>% which()
incomplete_samples <- c(missing_vf, missing_m)
slice(dat, incomplete_samples)
length(incomplete_samples)
if (length(incomplete_samples)>0) {
  dat <- slice(dat, -c(incomplete_samples))
}

# filter vectorfields with masks
dat$filtered <- map2(dat$mask, dat$vectorf, filter_vectors)
dat

dat <- mutate(dat, filtered = map2(mask, vectorf, filter_vectors))
dat

# print overview
dat %>% print(n = nrow(.))
dat %>% group_by(donor, day, k, img) %>% summarise(n = n())


# plot --------------------------------------------------------------------

datl <- dat %>% select(-mask, -vectorf) %>% unnest(filtered)
ggplot(datl, aes(Orientation, color = k, fill = k)) +
  # geom_histogram(bins = 90, alpha = 0.5) +
  # geom_freqpoly(show.legend = FALSE) +
  geom_density(alpha = 0.6, show.legend = TRUE) +
  labs(x = "Direction [°]", y = "Density", 
       fill = element_blank(), 
       color = element_blank()) +
  facet_wrap(~day, nrow = 2)

# ggsave(filename = "P2-figures/240129-alignment/240229-histo-facet.svg",
# width = 7, height = 6, units = "cm")

means1 <- datl %>% group_by(donor, day, k, img) %>% summarise(mean = mean(Orientation),
                                                   sd = sd(Orientation))

# save CSV
# means1 %>% select(donor, day, k, img, mean, sd) %>% 
#   write_csv(., file = "alignment1.csv")


# FWHM --------------------------------------------------------------------
# fit normal distribiution and extract mean and SD instead of FWHM

# fit <- MASS::fitdistr(d2$orientation, "normal")
# fit$estimate

datf <- dat %>% mutate(fit = map(filtered, ~MASS::fitdistr(.$Orientation, "normal"))) %>% 
  mutate(mean = map_dbl(fit, ~.$estimate[1]),
         sd = map_dbl(fit, ~.$estimate[2]))
datf

# save CSV
# d3 %>% select(donor, day, k, img, mean, sd) %>% 
#   write_csv(., file = "alignment_fit.csv")
