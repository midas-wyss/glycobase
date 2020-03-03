library(RColorBrewer)

# Plot color palettes
PLOT_COLORS <- brewer.pal(11, 'Spectral')
PLOT_SHAPES <- 21:25

titlify <- function(s){
  to_title <- function(ss){
    ss = paste0(toupper(substr(ss,1,1)), substr(ss,2,nchar(ss)))
    ss = gsub('_', ' ', ss)
    ss = gsub(' ic', ' IC', ss)
    return(ss)
  }
  if (length(s) > 1){
    return(sapply(s, to_title))
  } else{
    return(to_title(s))
  }
}

#titlify_glycoletter <- function(s){
#  if (grepl('^[a|b][1:9]-[1:9]', s)){
#    return()
#  }
#}