## ----setup,include=FALSE------------------------------------------------------
# Set eval to TRUE to create Figures.
# Set echo to TRUE for html, but to FALSE for pdf.
knitr::opts_chunk$set(eval=FALSE,echo=TRUE,fig.path="images/")
eval <- FALSE # TRUE or FALSE

## ----functions----------------------------------------------------------------
#  ### Loading functions. ###
#  
#  inst <- rownames(utils::installed.packages())
#  
#  cran <- c("devtools","R.utils","Matrix","glmnet","pROC","BiocManager","ashr")
#  # "googledrive", "httpuv"
#  if(!all(cran %in% inst)){
#      for(i in seq_along(cran)){
#          if(!cran[i] %in% inst){
#              install.packages(cran[i])
#          }
#      }
#  }
#  
#  bioc <- c("edgeR","TCGAbiolinks")
#  if(!all(bioc %in% inst)){
#      #source("http://bioconductor.org/biocLite.R")
#      for(i in seq_along(bioc)){
#          if(!bioc[i] %in% inst){
#              #biocLite(bioc[i])
#              BiocManager::install(bioc[i])
#          }
#      }
#  }
#  
#  #if(!"ashr" %in% inst){
#  #  devtools::install_github("stephens999/ashr")
#  #}
#  
#  user <- Sys.getenv("USERNAME")
#  path <- file.path("C:","Users",user,"Desktop","palasso")
#  if(user=="arra"){path <- "C:/Users/arra/Desktop/MATHS/palasso_desktop"}
#  if(user==""){path <- "/virdir/Scratch/arauschenberger/palasso"}
#  setwd(path)
#  folders <- c("data","results")
#  invisible(sapply(folders,function(x) if(!dir.exists(x)){dir.create(x)}))
#  
#  if(user!="arra"){
#      devtools::install_github("kkdey/CorShrink") # ref="a9f6ba0"
#      devtools::install_github("rauschenberger/palasso") # ref="4a995a2"
#  }
#  
#  if(FALSE){
#  
#      # The functions <<save>>, <<file.exists>> and <<file.remove>> access the hard disk, but also try to access googledrive.
#  
#      save <- function(object,file){
#          base::save(object,file=file)
#          tryCatch(expr=googledrive::drive_upload(media=file,path=file),
#                   error=function(x) NULL)
#          #Sys.sleep(0.5)
#      }
#  
#      file.exists <- function(file){
#          offline <- base::file.exists(file)
#          online <- FALSE
#          if(!offline){
#              d <- googledrive::as_dribble(x=file)
#              online <- tryCatch(expr=googledrive::some_files(d),
#                                 error=function(x) FALSE)
#              #Sys.sleep(0.5)
#          }
#          return(offline|online)
#      }
#  
#      file.remove <- function(file){
#          base::file.remove(file)
#          tryCatch(expr=googledrive::drive_trash(file=file),
#               error=function(x) NULL)
#          #Sys.sleep(0.5)
#      }
#  
#  
#  # The function <<update>> moves files from the research cloud to the remote drive. Given both paths, it first verifies whether the folders SIM, GDC and CCA are available, and then copies all missing files from the research cloud to the remote drive.
#  
#  # from: path to the origin
#  # to: path to the destination
#  
#  update <- function(from,to){
#      dir <- c("SIM","GDC","CCA")
#      if(any(!dir.exists(file.path(from,dir)))){stop("Invalid.")}
#      if(any(!dir.exists(file.path(to,dir)))){stop("Invalid.")}
#      pb <- utils::txtProgressBar(min=0,max=1,style=3)
#      for(i in seq_along(dir)){
#          files0 <- dir(file.path(from,dir[i]))
#          files1 <- dir(file.path(to,dir[i]))
#          names <- files0[!files0 %in% files1]
#          for(j in seq_along(names)){
#              utils::setTxtProgressBar(pb=pb,value=(i-1)/3+(j*i)/(3*length(names)))
#              file.copy(from=file.path(from,dir[i],names[j]),
#                        to=file.path(to,dir[i],names[j]),
#                        copy.date=TRUE)
#          }
#          utils::setTxtProgressBar(pb=pb,value=i/3)
#      }
#  }
#  
#  # update(from="results",to="//tsclient/N/palasso/results")
#  
#  }
#  

## ----get_isoform,eval=FALSE---------------------------------------------------
#  ### Downloading "Isoform Expression Quantification". ###
#  
#  #rm(list=ls())
#  #<<functions>>
#  
#  directory <- file.path(path,"data")
#  setwd(directory)
#  
#  # Retrieving cancer types:
#  project <- TCGAbiolinks::getGDCprojects()$id
#  project <- project[grepl(x=project,pattern="TCGA")]
#  
#  # Downloading isoform expression data:
#  y <- X <- list()
#  for(i in seq_along(project)){
#      query <- TCGAbiolinks::GDCquery(project=project[i],
#                  data.category="Transcriptome Profiling",
#                  data.type="Isoform Expression Quantification")
#      TCGAbiolinks::GDCdownload(query,method="api",directory=directory)
#      trace(TCGAbiolinks:::readTranscriptomeProfiling,tracer=quote(ignore.case<-TRUE))
#      X[[i]] <- TCGAbiolinks::GDCprepare(query,directory=directory)
#      X[[i]][,c("miRNA_ID","reads_per_million_miRNA_mapped",
#                "cross-mapped","miRNA_region")] <- NULL
#      y[[i]] <- rep(project[i],times=length(unique(X[[i]]$barcode)))
#  }
#  
#  save(list=c("y","X"),file=file.path(path,"data","isoform_raw.RData"))
#  load(file.path(path,"data","isoform_raw.RData"),verbose=TRUE)
#  
#  # Merging isoform expression data:
#  Xs <- do.call(what=rbind,args=X) # sparse matrix
#  y <- do.call(what="c",args=y)
#  
#  # Transform to matrix
#  Xs$isoform_coords <- gsub(pattern="hg38:chr",replacement="",x=Xs$isoform_coords)
#  samples <- unique(Xs$barcode)
#  covariates <- unique(Xs$isoform_coords)
#  row <- match(Xs$barcode,samples)
#  col <- match(Xs$isoform_coords,covariates)
#  X <- Matrix::sparseMatrix(i=row,j=col,x=Xs$read_count,dimnames=list(samples,covariates))
#  
#  # Order by molecular location
#  split <- strsplit(x=colnames(X),split=":|-")
#  chr <- sapply(split,function(x) x[[1]])
#  pos <- sapply(split,function(x) x[[2]])
#  order <- order(chr,pos)
#  X <- X[,order]
#  
#  if(FALSE){ # testing
#      i <- sample(seq_len(nrow(Xs)),size=1)
#      Xs$read_count[i]
#      X[Xs$barcode[i],Xs$isoform_coords[i]]
#  }
#  
#  save(list=c("y","X"),file=file.path(path,"data","isoform_all.RData"))

## ----get_miRNA,eval=FALSE-----------------------------------------------------
#  ### Downloading "miRNA Expression Quantification". ###
#  
#  #rm(list=ls())
#  #<<functions>>
#  
#  directory <- file.path(path,"data")
#  setwd(directory)
#  
#  # Downloading data.
#  project <- TCGAbiolinks::getGDCprojects()$id
#  project <- project[grepl(x=project,pattern="TCGA")]
#  y <- X <- list()
#  for(i in seq_along(project)){
#      query <- TCGAbiolinks::GDCquery(project=project[i],
#                             data.category="Transcriptome Profiling",
#                             data.type="miRNA Expression Quantification")
#      TCGAbiolinks::GDCdownload(query,method="api",directory=directory)
#      trace(TCGAbiolinks:::readTranscriptomeProfiling,tracer=quote(ignore.case<-TRUE))
#      data <- TCGAbiolinks::GDCprepare(query,directory=directory)
#      X[[i]] <- t(data[,c(seq(from=2,to=ncol(data),by=3))])
#      y[[i]] <- rep(project[i],times=nrow(X[[i]]))
#  }
#  
#  save(list=c("y","X"),file=file.path(path,"data","miRNA_raw.RData"))
#  load(file.path(path,"data","miRNA_raw.RData"))
#  
#  X <- do.call(what=rbind,args=X)
#  y <- do.call(what="c",args=y)
#  rownames(X) <- gsub(pattern="read_count_",replacement="",x=rownames(X))
#  
#  save(list=c("y","X"),file=file.path(path,"data","miRNA_all.RData"))

## ----get_gene,eval=FALSE------------------------------------------------------
#  ### Downloading "Gene Expression Quantification". ###
#  
#  #rm(list=ls())
#  #<<functions>>
#  
#  directory <- file.path(path,"data")
#  setwd(directory)
#  
#  # Retrieving cancer types:
#  project <- TCGAbiolinks::getGDCprojects()$id
#  project <- project[grepl(x=project,pattern="TCGA")]
#  
#  # Downloading data:
#  memory.limit(size=16000) # Activate virtual memory in system control!
#  y <- X <- list()
#  for(i in seq_along(project)){
#      query <- TCGAbiolinks::GDCquery(project=project[i],
#                  data.category="Transcriptome Profiling",
#                  data.type="Gene Expression Quantification",
#                  workflow.type="HTSeq - Counts"); gc()
#      TCGAbiolinks::GDCdownload(query=query,method="api",directory=directory); gc()
#      trace(TCGAbiolinks:::readTranscriptomeProfiling,tracer=quote(ignore.case<-TRUE)); gc()
#      X[[i]] <- TCGAbiolinks::GDCprepare(query,directory=directory); gc()
#      y[[i]] <- rep(project[i],times=ncol(X[[i]])); gc()
#  }
#  
#  save(list=c("y","X"),file=file.path(path,"data","gene_raw.RData"))
#  load(file.path(path,"data","gene_raw.RData"))
#  
#  genes <- SummarizedExperiment::rowData(X[[1]])
#  mart <- biomaRt::useMart("ensembl",dataset="hsapiens_gene_ensembl") #
#  char <- biomaRt::getBM(attributes=c("ensembl_gene_id","chromosome_name","transcript_start","gene_biotype"),filters=c("biotype","chromosome_name"),values=list("protein_coding",c(1:22,"X")),mart=mart)
#  select <- genes$ensembl_gene_id[genes$ensembl_gene_id %in% char$ensembl_gene_id]
#  
#  X <- lapply(X,function(x) t(SummarizedExperiment::assays(x)$"HTSeq - Counts"[select,]))
#  X <- do.call(what=rbind,args=X)
#  y <- do.call(what="c",args=y)
#  
#  save(list=c("y","X"),file=file.path(path,"data","gene_all.RData"))

## ----get_CNV,eval=FALSE-------------------------------------------------------
#  ### Downloading "Copy Number Variation". ###
#  
#  #rm(list=ls())
#  #<<functions>>
#  
#  directory <- file.path(path,"data")
#  setwd(directory)
#  
#  project <- TCGAbiolinks::getGDCprojects()$id
#  project <- project[grepl(x=project,pattern="TCGA")]
#  
#  y <- X <- list()
#  for(i in seq_along(project)){
#      query <- TCGAbiolinks::GDCquery(project=project[i],
#                  data.category="Copy Number Variation",
#                  data.type="Masked Copy Number Segment")
#      TCGAbiolinks::GDCdownload(query=query,method="api",directory=directory)
#      trace(TCGAbiolinks:::readTranscriptomeProfiling,tracer=quote(ignore.case<-TRUE))
#      X[[i]] <- TCGAbiolinks::GDCprepare(query,directory=directory)
#      y[[i]] <- rep(project[i],times=length(unique(X[[i]]$Sample))) # correct?
#  }
#  
#  save(list=c("y","X"),file=file.path(path,"data","CNV_raw.RData"))
#  load(file.path(path,"data","CNV_raw.RData"),verbose=TRUE)
#  
#  # Merging CNV data:
#  Xs <- do.call(what=rbind,args=X) # sparse matrix
#  y <- do.call(what="c",args=y)
#  #table(Xs$Sample)
#  
#  # Prepare cutting.
#  cut <- list()
#  cut$chr <- c(1:22,"X")
#  cut$start <- sapply(cut$chr,function(x) min(Xs$Start[Xs$Chromosome==x]))
#  cut$end <- sapply(cut$chr,function(x) max(Xs$End[Xs$Chromosome==x]))
#  cut$length <- cut$end-cut$start
#  cut$dist <- sum(cut$length)/10000
#  cut$num <- round(cut$length/cut$dist)
#  
#  # Create covariates.
#  cov <- list()
#  cov$p <- sum(cut$num)
#  cov$chromosome <- unlist(sapply(cut$chr,function(i) rep(i,times=cut$num[i])))
#  cov$location <- unlist(sapply(cut$chr,function(i) round(seq(from=cut$start[i],to=cut$end[i],length.out=cut$num[i]))))
#  cov$name <- paste0(cov$chromosome,":",cov$location)
#  
#  # Create indices for each covariate.
#  index <- rep(list(integer()),times=cov$p)
#  pb <- utils::txtProgressBar(min=0,max=cov$p,style=3)
#  for(j in seq_len(cov$p)){
#      utils::setTxtProgressBar(pb=pb,value=j)
#      index[[j]] <- which((Xs$Chromosome==cov$chromosome[j]) &
#          (Xs$Start<=cov$location[j]) & (cov$location[j]<=Xs$End)) # consider <
#  }
#  
#  # Expand indices to matrix.
#  X <- matrix(0,nrow=length(unique(Xs$Sample)),ncol=cov$p,
#               dimnames=list(unique(Xs$Sample),cov$name))
#  for(j in seq_along(index)){
#      mean <- Xs$Segment_Mean[index[[j]]]
#      i <- Xs$Sample[index[[j]]]
#      X[i,j] <- mean
#  }
#  
#  if(FALSE){ # test
#      sample <- sample(rownames(X),size=1)
#      covariate <- sample(colnames(X),size=1)
#      split <- strsplit(covariate,split=":")[[1]]
#      a <- X[sample,covariate]
#      b <- Xs$Segment_Mean[(Xs$Sample==sample) & (Xs$Chromosome==split[1]) & (Xs$Start<=as.numeric(split[2])) & (as.numeric(split[2]) < Xs$End)]
#      all(a==b)
#  }
#  
#  save(list=c("y","X","index"),file=file.path(path,"data","CNV_all.RData"))

## ----do_filter,eval=FALSE-----------------------------------------------------
#  ### Extracting samples of interest. ###
#  
#  #rm(list=ls())
#  #<<functions>>
#  
#  type <- c("isoform","miRNA","CNV","gene")
#  
#  for(i in seq_along(type)){
#      cat(type[i],"\n")
#      load(file.path(path,"data",paste0(type[i],"_all.RData")),verbose=TRUE)
#  
#      # TCGA barcode
#      barcode <- rownames(X)
#      code <- sapply(barcode,function(x) strsplit(x,split="-"))
#      code <- as.data.frame(do.call(what=rbind,args=code))
#      colnames(code) <- c("project","TSS","participant","sample_vial",
#                          "portion_analyte","plate","center")
#      code$sample <- substr(code$sample_vial,start=1,stop=2)
#      code$vial <- substr(code$sample_vial,start=3,stop=3)
#      code$portion <- substr(code$portion_analyte,start=1,stop=2)
#      code$analyte <- substr(code$portion_analyte,start=3,stop=3)
#      code$sample_vial <- code$portion_analyte <- NULL
#  
#      # solid tumour (except blood for LAML)
#      solid <- (code$sample=="01" | (y=="TCGA-LAML" & code$sample=="03"))
#      X <- X[solid,]
#      y <- y[solid]
#  
#      # unique samples
#      unique <- !duplicated(substr(rownames(X),start=1,stop=12))
#      X <- X[unique,]
#      y <- y[unique]
#  
#      save(list=c("y","X"),file=file.path(path,"data",paste0(type[i],"_sub.RData")))
#  }
#  
#  # isoform: n=9'794, p=194'595, k=32
#  # miRNA: n=9'794, p=1'881, k=32
#  # gene: n=9'830, p=19'602, k=33
#  # CNV: n=10'578, p=10'000, k=33
#  
#  ## Understanding barcodes:
#  # overview: https://wiki.nci.nih.gov/display/TCGA/TCGA+barcode
#  # details: https://gdc.cancer.gov/resources-tcga-users/tcga-code-tables
#  
#  ## Understanding replicate samples:
#  # http://gdac.broadinstitute.org/runs/sampleReports/latest/READ_Replicate_Samples.html

## ----do_predict,eval=FALSE----------------------------------------------------
#  ### Analysing the TCGA data. ###
#  
#  #rm(list=ls())
#  #<<functions>>
#  
#  for(type in c("miRNA","isoform","CNV","gene")){
#    library(Matrix)
#    for(k in c(207,sample(528))){
#      set.seed(k); cat(k," ")
#      if(type %in% c("isoform","miRNA") & k > 496){next}
#      if(type %in% c("CNV","gene") & k > 528){next}
#  
#      # searching for missing cancer-cancer combinations
#      rm(list=setdiff(ls(),c("k","type","path","save","file.exists","file.remove"))); gc()
#      file0 <- paste0("results/",type,"_start_",k,".RData")
#      file1 <- paste0("results/",type,"_loss_",k,".RData")
#      if(file.exists(file0)||file.exists(file1)){next}
#      save(object=k,file=file0)
#      load(paste0("data/",type,"_sub.RData"))
#  
#      # indicating the cancer-cancer combination
#      cancer <- substring(text=unique(y),first=6)
#      comb <- utils::combn(x=cancer,m=2)
#      select <- paste0("TCGA-",comb[,k])
#      y <- ifelse(y==select[1],1,ifelse(y==select[2],0,NA))
#      rm(cancer,select)
#  
#      # removing other cancer types
#      cond <- !is.na(y)
#      y <- y[cond]
#      X <- X[cond,]
#      rm(cond)
#  
#      # pre-processing
#      if(type %in% c("isoform","miRNA")){
#        x <- palasso:::.prepare(X,cutoff="zero")
#      } else if(type=="gene"){
#        x <- palasso:::.prepare(X,cutoff="knee")
#      } else if(type=="CNV"){
#        x <- list(X=X,Z=sign(X))
#        x <- lapply(x,function(x) scale(x))
#        attributes(x)$info <- data.frame(n=nrow(X),p=ncol(X),prop=mean(x$Z==0))
#      }
#      rm(X)
#  
#      # cross-validation
#      loss <- tryCatch(expr=palasso:::.predict(y=y,X=x,nfolds.int=10),error=function(e) palasso:::.predict(y=y,X=x,nfolds.int=10))
#  
#      # information
#      loss$info <- cbind(k=k,
#                         y0=comb[2,k],
#                         y1=comb[1,k],
#                         n0=sum(y==0),
#                         n1=sum(y==1),
#                         attributes(x)$info,
#                         loss$info)
#  
#      # refit
#      object <- palasso::palasso(y=y,X=x,nfolds=10,family="binomial",standard=TRUE,elastic=TRUE,shrink=TRUE)
#  
#      model <- c(names(object),"elastic",
#                 paste0("paired.",c("adaptive","standard","combined")))
#  
#      for(max in c(10,50,Inf)){
#        temp <- list()
#        temp$nzero <- data.frame(model=model,x=NA,z=NA)
#        for(i in seq_along(model)){
#          coef <- palasso:::coef.palasso(object=object,model=model[i],max=max)
#          temp$nzero$x[i] <- sum(coef$x!=0)
#          temp$nzero$z[i] <- sum(coef$z!=0)
#        }
#        temp$select <- palasso:::subset.palasso(x=object,max=max,
#                                                model="paired.adaptive")$palasso$select
#        temp$weights <- palasso:::weights.palasso(object=object,max=max,
#                                                  model="paired.adaptive")
#        temp$coef <- palasso:::coef.palasso(object=object,max=max,
#                                            model="paired.adaptive")
#        loss[[paste0("fit",max)]] <- temp
#      }
#  
#      save(object=loss,file=file1)
#      file.remove(file0)
#    }
#  
#    index <- sum(grepl(dir(),pattern="sessionInfo"))
#    sink(paste0("sessionInfo",index+1,".txt"))
#    date()
#    utils::sessionInfo()
#    devtools::session_info()
#    sink()
#  
#  }

## ----collect------------------------------------------------------------------
#  # The function <<collect>> loads all files from PATH including PATTERN in the file name, loads OBJECT into a list, and executes a function call.
#  #<<functions>>
#  
#  # path: folder
#  # pattern: character, or NULL (all files)
#  # object: character vector, or NULL (all objects)
#  # what: function call
#  
#  collect <- function(path=getwd(),pattern="",object=NULL,what="rbind"){
#      OBJECT = object
#      # identify files
#      files <- dir(path)
#      files <- files[grepl(x=files,pattern=pattern)]
#      files <- files[grepl(x=files,pattern=".RData")]
#      number <- gsub(pattern=paste0(pattern,"|.RData"),replacement="",x=files)
#      files <- files[order(as.numeric(number))] # trial1
#      names <- gsub(pattern=".RData",replacement="",x=files) # trial1
#      if(length(files)==0){stop("Invalid datasets.")}
#      # load data
#      all <- list()
#      for(i in seq_along(files)){
#          x <- load(file.path(path,files[i]))
#          x <- eval(parse(text=x))
#          if(is.null(OBJECT)){
#              all[[i]] <- x
#              names(all)[i] <- names[i]
#          } else {
#              for(j in seq_along(OBJECT)){
#                  all[[OBJECT[j]]][[i]] <- x[[OBJECT[j]]]
#                  names(all[[OBJECT[j]]])[i] <- names[i]
#              }
#          }
#      }
#      # fuse data
#      if(is.null(OBJECT)){
#          all <- do.call(what=what,args=all)
#      } else {
#          all <- lapply(all,function(x) do.call(what=what,args=x))
#      }
#      return(all)
#  }
#  
#  LOSS <- list()
#  type <- c("gene","isoform","miRNA","CNV")
#  #type <- "miRNA"
#  for(i in seq_along(type)){
#    LOSS[[type[i]]] <- collect(path="results",
#                               pattern=paste0(type[i],"_loss_"),
#                               object=c("deviance","auc","class","info",
#                                        paste0("fit",c(10,50,Inf))))
#  }
#  for(i in seq_along(LOSS)){
#    for(j in 1:3){
#      colnames(LOSS[[i]][[j]])[colnames(LOSS[[i]][[j]])=="paired.adaptive"] <- "paired"
#    }
#  }
#  
#  #type <- "gene"
#  #a <- LOSS[[type]]$deviance[rownames(LOSS[[type]]$deviance)=="10","paired"]
#  #b <- LOSS[[type]]$deviance[rownames(LOSS[[type]]$deviance)=="10","elastic"]
#  #mean(a<b)
#  

## ----do_test,eval=eval--------------------------------------------------------
#  ### Testing for significant differences. ###
#  
#  #rm(list=ls())
#  #<<functions>>
#  #<<collect>>
#  
#  row <- c("gene","isoform","miRNA","CNV")
#  col <- c("10","Inf")
#  lay <- c("standard_x","standard_z","standard_xz",
#           "adaptive_x","adaptive_z","adaptive_xz",
#           "elastic") # added "elastic"
#  
#  M <- array(NA,dim=c(length(row),length(col),length(lay)),dimnames=list(row,col,lay))
#  
#  for(i in seq_along(row)){
#  
#    loss <- LOSS[[row[i]]][c("info","deviance")]
#  
#    y0 <- as.character(loss$info$y0)
#    y1 <- as.character(loss$info$y1)
#    cancer <- sort(unique(c(y0,y1)))
#    Z <- palasso:::.design(x=cancer)
#  
#    for(j in seq_along(col)){
#  
#      # differences
#      cond <- rownames(loss$deviance)==col[j]
#  
#      for(k in seq_along(lay)){
#  
#        fill <- loss$deviance[cond,lay[k]] - loss$deviance[cond,"paired"]
#        X <- matrix(NA,nrow=length(cancer),ncol=length(cancer),
#                    dimnames=list(cancer,cancer))
#        X[cbind(y0,y1)] <- X[cbind(y1,y0)] <- fill
#        X[lower.tri(X)] <- NA
#  
#        # p-values
#        pvalue <- rep(NA,times=max(Z))
#        for(l in seq_len(max(Z))){
#          x <- as.numeric(X[Z==l])
#          if(col[j]=="10"){
#            alternative <- "greater" # Never use "two.sided"!
#          }
#          if(col[j]=="Inf"){
#            alternative <- "less" # Never use "two.sided"!
#          }
#          pvalue[l] <- stats::wilcox.test(x=x,alternative=alternative,
#                                   exact=FALSE)$p.value
#        }
#  
#        # Simes
#        M[i,j,k] <- palasso:::.combine(pvalue,method="simes")
#      }
#    }
#  }
#  
#  # Table SIG: significance
#  constraint <- "10"
#  table <- format(M[,constraint,1:6],digits=1,scientific=FALSE)
#  for(i in seq_len(nrow(table))){
#      for(j in seq_len(ncol(table))){
#          if(M[i,constraint,j]>=0.05){
#              table[i,j] <- paste0("{\\color{gray}{",table[i,j],"}}")
#          }
#      }
#  }
#  one <- c("","\\text{standard}","","","\\text{adaptive}","")
#  two <- paste0("\\text{",c("x","z","xz","x","z","xz"),"}")
#  rownames(table) <- paste0("\\text{",rownames(table),"}")
#  table <- rbind(one,two,table,deparse.level=0)
#  rownames(table)[1] <- "~"
#  xtable <- xtable::xtable(table,align=c("r","|","c","c","c","|","c","c","c"))
#  xtable::print.xtable(xtable,type="latex",include.colnames=FALSE,sanitize.text.function=identity)

## ----do_elastic,eval=eval-----------------------------------------------------
#  ### Comparison with elastic net. ###
#  #rm(list=ls())
#  #<<functions>>
#  #<<collect>>
#  
#  row <- c("gene","isoform","miRNA","CNV")
#  col <- c("10","50","Inf")
#  better <- worse <- less <- matrix(NA,nrow=length(row),ncol=length(col),
#                   dimnames=list(row,col))
#  for(i in seq_along(row)){
#    for(j in seq_along(col)){
#      # proportion of improvements (cross-validation)
#      cond <- rownames(LOSS[[row[i]]]$deviance)==col[j]
#      loss <- LOSS[[row[i]]]$deviance[cond,c("paired","elastic")]
#      better[i,j] <- round(mean(loss[,"paired"]<loss[,"elastic"]),digits=2)
#      worse[i,j] <- round(mean(loss[,"paired"]>loss[,"elastic"]),digits=2)
#      # average difference in nzero (refitted models)
#      df_paired <- apply(LOSS[[row[i]]][[paste0("fit",col[j])]],1,function(x)   sum(x$nzero[x$nzero[,"model"]=="paired.adaptive",c("x","z")]))
#      df_elastic <- apply(LOSS[[row[i]]][[paste0("fit",col[j])]],1,function(x)   sum(x$nzero[x$nzero[,"model"]=="elastic95",c("x","z")]))
#      df_diff <- df_elastic-df_paired
#      less[i,j] <- round(mean(df_diff),digits=2)
#      #graphics::hist(df_diff,main=paste(row[i],col[j]),xlim=c(-1,1)*max(abs(df_diff)))
#    }
#  }
#  better
#  worse
#  less

## ----do_refit,eval=eval-------------------------------------------------------
#  ### Analysing the refitted models. ###
#  
#  #rm(list=ls())
#  #<<functions>>
#  #<<collect>>
#  
#  # Table SEL: selected model
#  nzero <- paste0("fit",c(5,10,Inf))
#  model <- c(paste0("standard_",c("x","z","xz")),
#             paste0("adaptive_",c("x","z","xz")),
#             "between_xz","within_xz")
#  type <- c("gene","isoform","miRNA","CNV")
#  table <- array(NA,dim=c(length(nzero),length(model),length(type)),
#                 dimnames=list(nzero,model,type))
#  for(i in seq_along(nzero)){
#      for(j in seq_along(model)){
#          for(k in seq_along(type)){
#              sub <- LOSS[[type[k]]][[nzero[i]]]
#              table[i,j,k] <- sum(sub[,"select"]==model[j])
#          }
#      }
#  }
#  colSums(table["fit10",,]) # CHECK WHETHER COMPLETE!
#  table <- round(prop.table(table["fit10",,],margin=2),digits=2)
#  table <- t(table)
#  table <- table[,apply(table,2,function(x) any(x!=0))]
#  rownames(table) <- paste0("\\text{",rownames(table),"}")
#  xtable <- xtable::xtable(table,align=c("r","|","c","c","c","c"))
#  xtable::print.xtable(xtable,type="latex",include.colnames=FALSE,sanitize.text.function=identity)
#  
#  # selected weights and covariates
#  type <- c("gene","isoform","miRNA","CNV")
#  group <- c("x","z")
#  model <- c(paste0("standard_",c("x","z","xz")),
#             paste0("adaptive_",c("x","z","xz")),
#             "paired.adaptive","elastic") # added "elastic" , paste0("elastic",c(100,75,50,25))
#  weights10 <- weightsInf <- matrix(NA,nrow=length(group),ncol=length(type),
#                  dimnames=list(group,type))
#  coef10 <- coefInf <- array(NA,dim=c(length(group),length(type),length(model)),
#                 dimnames=list(group,type,model))
#  for(i in seq_along(group)){
#      for(j in seq_along(type)){
#          weights10[,j] <- rowMeans(sapply(LOSS[[type[j]]]$fit10[,"weights"],colMeans))
#          weightsInf[,j] <- rowMeans(sapply(LOSS[[type[j]]]$fitInf[,"weights"],colMeans))
#          for(k in seq_along(model)){
#              coef10[i,j,k] <- mean(sapply(LOSS[[type[j]]]$fit10[,"nzero"], function(x) sum(x[x$model==model[k],group[i]])))
#              coefInf[i,j,k] <- mean(sapply(LOSS[[type[j]]]$fitInf[,"nzero"], function(x) sum(x[x$model==model[k],group[i]])))
#          }
#      }
#  }
#  # coef10["x",,]+coef10["z",,]
#  
#  
#  # with sparsity constraint
#  round(prop.table(weights10,margin=2),2)
#  round(prop.table(coef10[,,"paired.adaptive"],margin=2),2)
#  round(colSums(coef10[,,"paired.adaptive"]),2)
#  
#  # natural sparsity
#  round(prop.table(weightsInf,margin=2),2)
#  round(prop.table(coefInf[,,"paired.adaptive"],margin=2),2)
#  round(colSums(coefInf[,,"paired.adaptive"]),2)
#  round(colSums(coefInf[,,"elastic"])/colSums(coefInf[,,"paired.adaptive"]),1) # multiple nzero of elastic net and paired lasso
#  
#  # Table NSC: number of non-zero coefficients
#  table <- round(coefInf["x",,]+coefInf["z",,])
#  colnames(table)[7] <- "paired"
#  one <- c("","\\text{standard}","","","\\text{adaptive}","","\\text{paired}","\\text{elastic}")
#  two <- paste0("\\text{",c("x","z","xz","x","z","xz","xz","xz"),"}")
#  rownames(table) <- paste0("\\text{",rownames(table),"}")
#  table <- rbind(one,two,table,deparse.level=0)
#  rownames(table)[1] <- "~"
#  xtable <- xtable::xtable(table,align=c("r","|","c","c","c","|","c","c","c","|","c","|","c"))
#  xtable::print.xtable(xtable,type="latex",include.colnames=FALSE,sanitize.text.function=identity)

## ----figure_CSW,fig.height=2,fig.cap="__Figure CSW:__ Weighting schemes. Each covariate pair ($y$-axis) receives weights for both parts ($x$-axis), here for simulated data."----
#  ### FIGURE CSW ###
#  
#  #rm(list=ls())
#  #<<functions>>
#  
#  set.seed(1)
#  overfit <- TRUE
#  
#  # simulate
#  n <- 10
#  cx <- stats::rbeta(n=n,shape1=0.9,shape2=1)
#  cz <- stats::rbeta(n=n,shape1=0.4,shape2=0.9)
#  
#  # collection
#  x <- list()
#  y <- list()
#  
#  # adaptive weights (X only)
#  x[[1]] <- rep(1,times=n)
#  if(overfit){x[[1]] <- cx}
#  y[[1]] <- rep(0,times=n)
#  
#  # adaptive weights (Z only)
#  x[[2]] <- rep(0,times=n)
#  y[[2]] <- rep(1,times=n)
#  if(overfit){y[[2]] <- cz}
#  
#  # adaptive weights (X and Z)
#  x[[3]] <- y[[3]] <- rep(0.5,times=n)
#  if(overfit){x[[3]] <- cx}
#  if(overfit){y[[3]] <- cz}
#  
#  # within-pair weights
#  x[[4]] <- cx^2/(cx+cz)
#  y[[4]] <- cz^2/(cx+cz)
#  
#  # visualisation
#  graphics::par(mfrow=c(1,4),mar=c(4.5,0.5,0.5,0.5),oma=c(0,2,0,0))
#  for(i in seq_len(4)){
#      palasso:::plot_pairs(x=x[[i]],y=y[[i]],lwd=4)
#      if(i==1){
#          graphics::mtext(text="covariate pair",side=2,line=1)
#      }
#  }

## ----figure_DIA,fig.height=3,fig.cap="__Figure DIA__: Sample size flowchart. \\textsc{tcga} provides suitable isomi\\textsc{r} data for $9\\,794$ samples (left), from $32$ cancer types (centre), forming $496$ cancer-cancer combinations (right). Each sample appears in $31$ combinations."----
#  ### FIGURE DIA ###
#  
#  #rm(list=ls())
#  #<<functions>>
#  
#  ellipse <- function(x,y,a=0.2,b=0.25,border=NA){
#      n <- max(c(length(x),length(y)))
#      if(length(x)==1){x <- rep(x,times=n)}
#      if(length(y)==1){y <- rep(y,times=n)}
#      if(length(border)==1){border <- rep(border,times=n)}
#      for(i in seq_len(n)){
#          angle <- seq(from=0,to=2*pi,length=100)
#          xs <- x[i] + a * cos(angle)
#          ys <- y[i] + b * sin(angle)
#          graphics::polygon(x=xs,y=ys,col=grey(0.9),border=border[i])
#      }
#  }
#  
#  cancer <- c("ACC","BLCA","BRCA","UVM")
#  number <- c(80,409,1078,80)
#  col <- grDevices::rgb(red=0,green=0,blue=sample(seq(from=75,to=255,length.out=length(number))),maxColorValue=255)
#  
#  lwd <- log(2*number)-2
#  lwd = pmax(5*number/max(number),1)
#  x1 <- 1.3; x2 <- 2; x3 <- 3
#  
#  set.seed(1)
#  
#  # first layer (bubble)
#  graphics::plot.new()
#  graphics::par(mar=c(0,0,0,0))
#  graphics::plot.window(xlim=c(1.1,3.3),ylim=c(-1.6,1.6))
#  ellipse(x=x1,y=0)
#  graphics::text(x=x1,y=0,labels="TCGA",font=2,adj=c(0.5,0))
#  graphics::text(x=x1,y=0,labels="n=9794",adj=c(0.5,1.2),cex=0.9)
#  
#  # second layer (colon)
#  y1 <- seq(from=1,to=-1,length.out=length(cancer)+1)
#  graphics::text(x=x2,y=y1[length(cancer)],labels="...",font=2,srt=90)
#  y1 <- y1[-length(cancer)]
#  
#  # first-second layer (connect)
#  graphics::segments(x0=x1+0.2,y0=0,x1=x2-0.2,y1=y1,lwd=lwd,col=col)
#  
#  # second layer (bubble)
#  ellipse(x=x2,y=y1,a=0.2,b=0.2)
#  graphics::text(x=x2,y=y1,labels=cancer,font=2,col=col,adj=c(0.5,0))
#  graphics::text(x=x2,y=y1,labels=paste0("n=",number,""),adj=c(0.5,1.2),cex=0.9)
#  
#  comb <- utils::combn(x=seq_along(y1),m=2)
#  
#  # third layer (colon)
#  y2 <- seq(from=1.5,to=-1.5,length.out=ncol(comb)+1)
#  graphics::text(x=x3,y=y2[ncol(comb)],labels="...",font=2,srt=90)
#  y2 <- y2[-ncol(comb)]
#  
#  # second-third layer (connect)
#  graphics::segments(x0=2.2,y0=y1[comb[1,]],x1=2.7,y1=y2,lwd=lwd[comb[1,]],col=col[comb[1,]])
#  graphics::segments(x0=2.2,y0=y1[comb[2,]],x1=2.7,y1=y2,lwd=lwd[comb[2,]],col=col[comb[2,]])
#  
#  # third layer (bubble)
#  ellipse(x=x3,y=y2,a=0.3,b=0.22)
#  graphics::text(x=x3,y=y2,labels=paste0(cancer[comb[1,]]," "),
#                 font=2,col=col[comb[1,]],adj=c(1,0))
#  graphics::text(x=x3,y=y2,labels=paste0(" ",cancer[comb[2,]]),
#                 font=2,col=col[comb[2,]],adj=c(0,0))
#  graphics::text(x=x3,y=y2,labels=":",font=2,adj=c(0.5,0))
#  labels <- apply(comb,2,function(x) sum(number[x]))
#  labels <- paste0("n=",labels,"")
#  graphics::text(x=x3,y=y2,labels=labels,adj=c(0.5,1.2),cex=0.9)
#  

## ----figure_CLA,fig.height=5,fig.width=6,message=FALSE,fig.cap="__Figure CLA:__ Predictive performance for genes, isomi\\textsc{r}s, mi\\textsc{rna}s and \\textsc{cnv}s (from top to bottom). The bar charts (left) count how often the paired lasso leads to a lower (dark) or higher (bright) deviance than the competing model. The box plots (right) show how much lower (dark) or higher (bright) the deviance is."----
#  ### FIGURE CLA ###
#  
#  #rm(list=ls())
#  #<<functions>>
#  
#  graphics::par(mfrow=c(4,2),oma=c(0,0,0,0),mar=c(2.1,3.5,0.5,0.5))
#  
#  for(type in c("gene","isoform","miRNA","CNV")){
#  
#      loss <- LOSS[[type]][c("deviance","auc","class")]
#      choice <- "paired"
#      loss <- lapply(loss,function(x) x[,c(paste0("standard_",c("x","z","xz")),paste0("adaptive_",c("x","z","xz")),choice)])
#  
#      for(constraint in c("10")){ # c("5","10","Inf")
#          # change
#          sub <- lapply(loss,function(x) x[rownames(x)==constraint,])
#          palasso:::plot_score(sub$deviance,choice=choice)
#          change <- sub$deviance[,7]-sub$deviance[,-7]
#          palasso:::plot_box(change,ylab="change",zero=TRUE,choice=NA)
#          # info
#          info <- list()
#          info$select <- names(which.min(apply(sub$deviance,2,median)[-7]))
#          info$DEV_paired <- median(sub$deviance[,choice])
#          info$DEV_select <- median(sub$deviance[,info$select])
#          info$improve <- mean(sub$deviance[,info$select]>sub$deviance[,choice])
#          info$AUC_paired <- median(sub$auc[,choice])
#          info$CLASS_paired <- median(sub$class[,choice])
#          print(as.data.frame(info)) # important
#      }
#  }

## ----figure_DEC,fig.height=4,fig.width=6,fig.cap="__Figure DEC:__ Model convergence for genes (top left), isomi\\textsc{r}s (top right), mi\\textsc{rna}s (bottom left) and \\textsc{cnv}s (bottom right). The median deviances ($y$-axis) of the standard (dotted), adaptive (dashed) and paired (solid) lasso converge as the sparsity constraint ($x$-axis) increases."----
#  ### FIGURE DEC ###
#  
#  #rm(list=ls())
#  #<<functions>>
#  
#  #graphics::par(oma=c(1.0,1.0,0,0),mar=c(1.5,3.0,0.5,0.5),mfrow=c(1,1))
#  graphics::par(oma=c(1.0,1.0,0,0),mar=c(1.5,3.0,0.5,0.5),mfrow=c(2,2))
#  
#  for(type in c("gene","isoform","miRNA","CNV")){
#      models <- c(paste0("standard_",c("x","z","xz")),
#                  paste0("adaptive_",c("x","z","xz")),"paired")
#      constraint <- c("3","4","5","10","15","20","25","50","Inf")
#  
#      loss <- LOSS[[type]]["deviance"]
#  
#      loss <- lapply(loss,function(x) x[,models])
#  
#      table <- matrix(NA,nrow=length(constraint),ncol=length(models),
#                      dimnames=list(constraint,models))
#      for(i in seq_along(constraint)){
#          sub <- lapply(loss,function(x) x[rownames(x)==constraint[i],])
#          table[i,] <- apply(sub$deviance,2,median)
#      }
#  
#      # table <- log(table)
#      graphics::plot.new()
#      graphics::plot.window(xlim=c(1,length(constraint)),ylim=range(table))
#      graphics::box()
#      constraint[constraint=="Inf"] <- "n"
#      graphics::axis(side=2)
#      graphics::axis(side=1,at=seq_along(constraint),labels=constraint,tick=FALSE,line=-1)
#  
#      for(k in c(1,2)){
#          for(i in seq_along(models)){
#              lty <- ifelse(i%in%c(1,2,3),3,ifelse(i%in%c(4,5,6),2,1))
#              col <- ifelse(i==7,"#00007F","#FF3535")
#              pch <- ifelse(i%in%c(1,4),"x",ifelse(i%in%c(2,5),"z",1))
#              if(k==1){
#                  graphics::lines(table[,i],col=col,lty=lty,lwd=2)
#                  graphics::points(table[,i],col="white",pch=16,cex=1.2)
#              } else {
#                  graphics::points(table[,i],col=col,pch=1,font=2)
#              }
#          }
#      }
#  }
#  graphics::title(ylab="deviance",line=0.0,outer=TRUE)
#  graphics::title(xlab="sparsity constraint",ylab="deviance",line=0.0,outer=TRUE)

## ----figure_CNV,fig.height=1.25,fig.width=6,fig.cap="__Figure CNV:__ Predictive performance for \\textsc{cnv}s. The box plots show how much the paired lasso improves (dark) or deteriorates (bright) the \\textsc{auc} (left) and misclassification rate (right) of the competing models."----
#  ### FIGURE CNV ###
#  
#  #rm(list=ls())
#  #<<functions>>
#  
#  graphics::par(oma=c(0,0,0,0),mar=c(2.1,3.5,0.5,0.5))
#  graphics::layout(matrix(c(1,1,2,2),nrow=1))
#  
#  loss <- LOSS[[type]][c("deviance","auc","class")]
#  loss <- lapply(loss,function(x) x[rownames(x)=="10",])
#  model <- c(paste0("standard_",c("x","z","xz")),
#             paste0("adaptive_",c("x","z","xz")))
#  
#  diff <- loss$auc[,"paired"]-loss$auc[,model]
#  palasso:::plot_box(diff,zero=TRUE,invert=TRUE,ylab="change")
#  diff <- loss$class[,"paired"]-loss$class[,model]
#  palasso:::plot_box(diff,zero=TRUE,ylab="change")

## ----figure_MAP,fig.height=4,fig.width=4,fig.cap="__Figure MAP:__ Cross-validated \\textsc{auc} for \\textsc{cnv}s. Each cell represents one cancer-cancer combination (row, column). The colour indicates whether the paired lasso leads to a low (dark) or high (bright) \\textsc{auc}."----
#  ### FIGURE MAP ###
#  
#  #rm(list=ls())
#  #<<functions>>
#  
#  loss <- LOSS[["CNV"]][c("info","auc")]
#  
#  cancer <- sort(unique(c(levels(loss$info$y0),levels(loss$info$y1))))
#  X <- matrix(NA,nrow=length(cancer),ncol=length(cancer),dimnames=list(cancer,cancer))
#  #Z <- palasso:::.design(x=cancer)
#  y0 <- as.character(loss$info$y0)
#  y1 <- as.character(loss$info$y1)
#  X[cbind(y0,y1)] <- X[cbind(y1,y0)] <- loss$auc[rownames(loss$auc)=="10","paired"]
#  
#  graphics::par(mar=c(0.5,3.0,3.0,0.5))
#  dimnames(X) <- lapply(dimnames(X),function(x) paste0("  ",x,"  "))
#  palasso:::plot_table(X=X,margin=-1,labels=FALSE,las=2,cex=0.7)
#  #sort(rowMeans(X,na.rm=TRUE),decreasing=TRUE)[1:2] # keep!

## ----figure_COM,fig.height=3.5,fig.width=4,fig.cap="__Figure COM:__ Group assignment for isomi\\textsc{r}s. Given $32$ cancer types, this matrix shows the assignment of $496$ dependent pairs to $31$ groups of $16$ independent pairs, with each symbol representing one group."----
#  ### FIGURE COM ###
#  
#  # 32 cancer types for isoform and miRNA
#  # 33 cancer types for gene and CNV
#  
#  #rm(list=ls())
#  #<<functions>>
#  
#  for(type in c("miRNA")){
#  
#  cancer <- sort(unique(as.character(unlist(LOSS[[type]]$info[,c("y0","y1")]))))
#  
#  n <- length(cancer)
#  z <- as.numeric(palasso:::.design(x=n))
#  x <- rep(seq_len(n),each=n)
#  y <- rep(seq(from=n,to=1,by=-1),times=n)
#  
#  pch <- z
#  pch[pch==0] <- NA
#  pex <- c(".","O","*","+","o","-","'","x")
#  
#  # colour
#  base <- grDevices::colorRampPalette(colors=c('darkblue','blue','red','darkred'))(n)
#  
#  col <- rep(NA,times=length(z))
#  col[z==0] <- "white"
#  for(i in seq_len(n)){
#      col[z==i] <- base[i]
#  }
#  
#  graphics::par(mfrow=c(1,1),mar=c(0,0,2,2))
#  graphics::plot.new()
#  graphics::plot.window(xlim=c(1,n),ylim=c(1,n))
#  graphics::points(x=x[pch<=25],y=y[pch<=25],
#                   pch=pch[pch<=25],col=col[pch<=25],cex=0.9)
#  graphics::points(x=x[pch>25],y=y[pch>25],
#                   pch=pex[(pch-25)[pch>25]],col=col[pch>25],cex=0.9)
#  graphics::segments(x0=0,x1=n+1,y0=n+1)
#  graphics::segments(x0=n+1,y0=n+1,y1=0)
#  graphics::segments(x0=0,x1=n+1,y0=n+1,y1=0,lty=2)
#  
#  graphics::mtext(text=cancer,side=3,at=1:n,las=2,cex=0.7)
#  graphics::mtext(text=cancer,side=4,at=n:1,las=2,cex=0.7)
#  
#  }

