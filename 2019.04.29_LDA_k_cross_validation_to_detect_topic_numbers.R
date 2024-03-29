source('./library_loader.R')
source("./utils.R")

# Initializing Data
t = initializeData()

for (p in 1:15) {
  # Preparing the data
  tm_13 = as.matrix(getTermMatrixWithTM(t, p, sparsity = 0.98, weightTf))
  dim(tm_13)
  tm_13 = unique(tm_13)
  dim(tm_13)
  tm_13 = tm_13[rowSums(tm_13) > 0,]
  
  ### k-Fold Cross Validation for determining the number of topics ####
  cluster <- makeCluster(12)
  registerDoParallel(cluster)
  
  clusterEvalQ(cluster, {
    library(topicmodels)
  })
  
  burnin = 1000
  iter = 1000
  keep = 50
  alpha = 0.1
  n <- nrow(tm_13)
  
  folds <- 5
  splitfolds <- sample(1:folds, n, replace = TRUE)
  candidate_k <- c(2, 3, 4, 5, 10, 20, 30, 40, 50, 60, 70, 80)
  clusterExport(cluster, c("tm_13", "burnin", "iter", "alpha", "keep", "splitfolds", "folds", "candidate_k"))
  
  system.time({
    results <- foreach(j = 1:length(candidate_k), .combine = rbind) %dopar%{
      k <- candidate_k[j]
      results_1k <- matrix(0, nrow = folds, ncol = 3)
      colnames(results_1k) <- c("k", "train_perplexity" , "test_perplexity")
      for(i in 1:folds){
        train_set <- tm_13[splitfolds != i , ]
        valid_set <- tm_13[splitfolds == i, ]
        
        fitted <- LDA(train_set, k = k, method = "Gibbs",
                      control = list(burnin = burnin, iter = iter, keep = keep, alpha = alpha) )
        results_1k[i,] <- c(k, perplexity(fitted, newdata = train_set), perplexity(fitted, newdata = valid_set))
        #####
        fitted_all <- LDA(tm_13, k = k, method = "Gibbs",
                          control = list(burnin = burnin, iter = iter, keep = keep, alpha = alpha) )
        rez = topicmodels::posterior(fitted_all)
        phi = rez$terms
        theta = rez$topics
        gamma = t(CalcGamma(phi, theta, p_docs = Matrix::rowSums(tm_13)))
        
        A = rbind(theta, gamma)
        KLMatrix <- KL(A)
        
        colors = c(rep(1, dim(theta)[1]), rep(2, dim(gamma)[1]))
        tsne = Rtsne(KLMatrix, dims = 2, perplexity=50, verbose=TRUE, max_iter = 2000, is_distance = T, pca = F)
        png(paste("T", p, "lda", k, "tsne.png", sep = "_"), width = 3200, height = 1600, res = 300)
        par(mfrow=c(1,2))
        plot(tsne$Y[,1], tsne$Y[,2],main=paste0(k, "_LDA + KL + NoPCA + tSNE"),xlab="Dim1", ylab = "Dim2", col = adjustcolor(colors, alpha=0.5), pch=16)
        legend("topleft",c("Users","Terms"), cex=.8, col=c("black","red"),pch=c(16,16))
        plot(tsne$Y[1: dim(theta)[1],1], tsne$Y[1: dim(theta)[1],2],xlab="Dim1", ylab = "Dim2", col = adjustcolor(colors, alpha=0.5), pch=16)
        legend("topleft",c("Users"), cex=.8, col=c("black"),pch=c(16))
        dev.off()
        ####
      }
      return(results_1k)
    }
  })
  stopCluster(cluster)
  
  results_df_mean = as.data.frame(results) %>%
    group_by(k) %>%
    summarise(train_perplexity = mean(train_perplexity), test_perplexity = mean(test_perplexity))
  
  title = paste("T", p, "k-CrossValidation_LDA_Topic_Number.png", sep = "_")
  png(title, width = 3200, height = 1600, res = 300)
  plot(main = paste0("5-fold CV of topic modelling with T", p),results_df_mean$k, results_df_mean$train_perplexity,
       pch = 16, col = 2, type = 'o', xlab = "No. topics", ylab = "Mean Perplexity on HoldOut Set", ylim = c(350, 510))
  lines(results_df_mean$k, results_df_mean$test_perplexity, pch = 16, col = 3, type = 'o')
  legend("topright",c("Train","Test"), cex=.8, col=c(2,3), pch=c(16,16))
  dev.off()
}






### Interactive plotting ####
# hover_text <- character(0)
# for (i in 1 : dim(theta)[1]) {
#   hover_text[i] = substr(as.character(T_[i, "text"]), 1, 200)
# }
# hover_text = c(hover_text, colnames(tm_13))
# 
# plotdata <- data.frame(tsne_x = tsne$Y[, 1], tsne_y = tsne$Y[, 2], hover_text = hover_text)
# plt2 <- ggplot(plotdata) + geom_point(aes(x = tsne_x, y = tsne_y, text = hover_text), color = adjustcolor(colors, alpha=0.5))
# ggplotly(plt2)
#####

