##### RNA-seq project downstream analysis #####
#####          FZIDT XiongYiFan           #####
#####          ewanxiong@gmail.ccom       ##### 

###############################################################################
# Part I DESeq2
###############################################################################
rm(list = ls())

suppressMessages(suppressWarnings(library(DESeq2)))
suppressMessages(suppressWarnings(library(ggplot2)))
suppressMessages(suppressWarnings(library(factoextra)))
suppressMessages(suppressWarnings(library(pheatmap)))
suppressMessages(suppressWarnings(library(ggpubr)))
suppressPackageStartupMessages(library(ggrepel))
suppressPackageStartupMessages(library(ggthemes))
suppressMessages(suppressWarnings(library(clusterProfiler)))
suppressMessages(suppressWarnings(library(org.Hs.eg.db)))

setwd("D:/RNA-seq/testdata/downstream/DEGs")


#merge multiple sampls

ctr1 <- read.table(file = "./ctr_1_counts.tsv",header = T,skip = 1,sep = "\t")
ctr2 <- read.table(file = "./ctr_2_counts.tsv",header = T,skip = 1,sep = "\t")
ctr3 <- read.table(file = "./ctr_3_counts.tsv",header = T,skip = 1,sep = "\t")
stroke1 <- read.table(file = "./stroke_1_counts.tsv",header = T,skip = 1,sep = "\t")
stroke2 <- read.table(file = "./stroke_2_counts.tsv",header = T,skip = 1,sep = "\t")
stroke3 <- read.table(file = "./stroke_3_counts.tsv",header = T,skip = 1,sep = "\t")

me1 <- merge(ctr1,ctr2, by = "Geneid")
me2 <- merge(me1,ctr3, by = "Geneid")
me3 <- merge(me2,stroke1, by = "Geneid")
me4 <- merge(me3,stroke2, by = "Geneid")
me5 <- merge(me4,stroke3, by = "Geneid")

index <- c("Geneid","ctr_1","ctr_2","ctr_3","stroke_1","stroke_2","stroke_3")


counts <- me5[,index]
view(counts)


raw_df <- read.table(file = "./293T-RNASeq-Ctrl_vs_KD.STAR.hg38.featureCounts.tsv",header = T,skip = 1,sep = "\t")
count_df <- raw_df[,c(7:10)]
rownames(count_df) <- as.character(raw_df[,1])
colnames(count_df) <- c("Ctrl_rep1","Ctrl_rep2","METTL3_KD_rep1","METTL3_KD_rep2")
head(count_df)


# -------------------------------------------------------->>>>>>>>>>
# make obj 
# -------------------------------------------------------->>>>>>>>>>
# filter 
colnames(count_df)
count_df.filter <- count_df[rowSums(count_df) > 20 & apply(count_df,1,function(x){ all(x > 0) }),]

# condition table
sample_df <- data.frame(
  condition = c(rep("ctrl",2), rep("KD",2)),
  cell_line = "293T"
)
rownames(sample_df) <- colnames(count_df.filter)

# -------------------------------------------------------->>>>>>>>>>
# step by step get test result 
# -------------------------------------------------------->>>>>>>>>>
dds <- DESeqDataSetFromMatrix(countData = count_df.filter, colData = sample_df, design = ~condition)

### sample cluster
vsd <- vst(dds,blind = TRUE)    #??????blind=TRUE????????????????????????????????????????????????????????????????????????????????????
sampleDists <- dist(t(assay(vsd))) 
res1 <- hcut(sampleDists, k = 2, stand = FALSE,hc_method ="average" ) 
fviz_dend(res1,
          rect_fill = T,# ????????????
          cex = 1,# ????????????
          color_labels_by_k=T,
          horiz=F)

### sample PCA
rld <- vst(dds, blind=FALSE)     #vst()???????????????rlog?????????????????????????????????
plotPCA(rld, intgroup="condition",ntop=1600)


### correlation heatmap

expcor <- cor(count_df.filter, method = "spearman")

pheatmap::pheatmap(expcor, clustering_method = "average",
                   treeheight_row = 0, treeheight_col = 0,
                   display_numbers = T)

pdf(file="D:/RNA-seq/downstream/sample_correlation.pdf",width = 10,height = 6)






# normalization 
dds <- estimateSizeFactors(dds)
sizeFactors(dds)

# dispersion
dds <- estimateDispersions(dds)
dispersions(dds)

# plot dispersion
plotDispEsts(dds, ymin = 1e-4)

# test 
dds <- nbinomWaldTest(dds)
res <- results(dds)



dds1 <- DESeq(dds)    # ???????????????
resultsNames(dds1)    # ?????????????????????
dds1$condition        #????????????????????????????????????????????????
res <- results(dds1)  
summary(res)          #?????????????????????????????????adjusted p????????? < 0.1???

table(res$padj < 0.05)        # filter
res <- res[order(res$padj),]  #??????padj??????????????????
resdata <- merge(as.data.frame(res), as.data.frame(counts(dds1, normalized=TRUE)),by="row.names",sort=FALSE)
diff_gene_deseq2 <-subset(res, padj < 0.05 & abs(log2FoldChange) > 1)   

### save file
write.csv(diff_gene_deseq2,file= "./DEGs_up_down.txt")  
write.table(diff_gene_deseq2,file= "./deg_up_down.txt", quote = F,sep = "\t")
#???????????????????????????
up_DEG <- subset(res, padj < 0.05 & log2FoldChange > 1)
down_DEG <- subset(res, padj < 0.05 & log2FoldChange < -1)
write.csv(up_DEG, "up_gene.csv")      
write.csv(down_DEG, "down_gene.csv")

#?????????????????????????????????????????????,??????????????????
#dim(diff_gene_deseq2)  
#dim(up_DEG)
#dim(down_DEG)

### volcano plot
deg_for_plot <- read.table("./deg_up_down.txt",header = T,sep = "\t")




deg_for_plot$logP <- -log10(deg_for_plot$padj) # ????????????????????????p-value??????log10()??????



#ggscatter(deg_for_plot, x = "log2FoldChange", y = "logP") + theme_base()

deg_for_plot$Group <- "not-siginficant"
deg_for_plot$Group[which((deg_for_plot$padj < 0.05) & deg_for_plot$log2FoldChange > 1)] = "up-regulated"
deg_for_plot$Group[which((deg_for_plot$padj < 0.05) & deg_for_plot$log2FoldChange < -1)] = "down-regulated"
table(deg_for_plot$Group)



ggscatter(deg_for_plot, x ="log2FoldChange",y = "logP",color = "Group", 
          palette = c("#2f5688","#cc0000"),
          size = 1) + theme_base()

ggsave(plot = last_plot(), file = "volcano_plot.pdf")



#????????????????????????not-siginficant???up???dowm
#???adj.P.value??????0.05???logFC??????2????????????????????????????????????
#???adj.P.value??????0.05???logFC??????-2????????????????????????????????????
DEG_data$Group <- "not-siginficant"
DEG_data$Group[which((DEG_data$padj < 0.05) & DEG_data$log2FoldChange > 1)] = "up-regulated"
DEG_data$Group[which((DEG_data$padj < 0.05) & DEG_data$log2FoldChange < -1)] = "down-regulated"
table(DEG_data$Group)
## 


up_label <- head(DEG_data[DEG_data$Group == "up-regulated",],1)
down_label <- head(DEG_data[DEG_data$Group == "down-regulated",],1)
deg_label_gene <- data.frame(gene = c(rownames(up_label),rownames(down_label)),
                             label = c(rownames(up_label),rownames(down_label)))
DEG_data$gene <- rownames(DEG_data)

DEG_data <- as.data.frame(DEG_data)

DEG_data <- merge(DEG_data,deg_label_gene,by = 'gene',all = T)

ggscatter(DEG_data,x = "log2FoldChange",y = "logP",
          color = "Group",
          palette = c("green","gray","red"),
          repel = T,
          ylab = "-log10(Padj)",
          size = 1) + 
  theme_base()+
  scale_y_continuous(limits = c(0,8))+
  scale_x_continuous(limits = c(-18,18))+
  geom_hline(yintercept = 1.3,linetype = "dashed")+
  geom_vline(xintercept = c(-2,2),linetype = "dashed")




# result as.data.frame
deseq2_res <- as.data.frame(diff_gene_deseq2)

################################################################################
###################    GO and KEGG enrichment analysis  ########################
################################################################################

# ??????????????????????????????gene id
gene <- row.names(deseq2_res)

# convert id
change_gene_ID = bitr(gene, fromType="SYMBOL", toType=c("ENSEMBL", "ENTREZID"), OrgDb="org.Hs.eg.db")
#head(change_gene_ID,2)

# ---------------------------------------------------------------------->>>>>>>
# GO analysis
# ---------------------------------------------------------------------->>>>>>>

erich.go = enrichGO(gene = change_gene_ID$ENTREZID,
                       OrgDb = org.Hs.eg.db,
                       keyType = "ENTREZID",
                       ont = "ALL",
                       pvalueCutoff = 0.5,
                       qvalueCutoff = 0.5)
dotplot(erich.go)
barplot(erich.go)

BP.go = enrichGO(gene = change_gene_ID$ENTREZID,
                 OrgDb = org.Hs.eg.db,
                 keyType = "ENTREZID",
                 ont = "BP",
                 pvalueCutoff = 0.5,
                 qvalueCutoff = 0.5)


plotGOgraph(BP.go)

# save image to file
pdf(file="D:/RNA-seq/downstream/enrich_go_Dotplot.pdf",width = 10,height = 6)
dotplot(erich.go)
dev.off()
pdf(file="D:/RNA-seq/downstream/enrich_go_barplot.pdf",width = 10,height = 6)
barplot(erich.go)
dev.off()
pdf(file="D:/RNA-seq/downstream/enrich_go_DAG.pdf",width = 10,height = 6)
plotGOgraph(BP.go)
dev.off()
# ---------------------------------------------------------------------->>>>>>>
# KEGG analysis
# ---------------------------------------------------------------------->>>>>>>


erich.kegg.res <- enrichKEGG(gene = change_gene_ID$ENTREZID,
                             organism = "hsa",
                             keyType = "kegg",
                             pvalueCutoff = 0.5)

barplot(erich.kegg.res)
dotplot(erich.kegg.res)

browseKEGG(erich.kegg.res, 'hsa04115')


# save image to file
pdf(file="D:/RNA-seq/downstream/enrich_KEGG_Dotplot.pdf",width = 10,height = 6)
dotplot(erich.kegg.res)
dev.off()
pdf(file="D:/RNA-seq/downstream/enrich_KEGG_barplot.pdf",width = 10,height = 6)
barplot(erich.kegg.res)
dev.off()



### GSEA analysis

library(enrichplot)
library(dplyr)
deg_for_gsea <- read.table("./deg_up_down.txt",header = T,sep = "\t")

gene <- deg_for_gsea$ID
#??????ID?????????????????????
gene=bitr(gene,fromType="SYMBOL",toType="ENTREZID",OrgDb="org.Hs.eg.db") 
#??????
gene <- dplyr::distinct(gene,SYMBOL,.keep_all=TRUE)

data_all <- merge(deg_for_gsea, gene, by.x = "ID", by.y = "SYMBOL")

data_all_sort <- data_all %>% 
  arrange(desc(log2FoldChange))
head(data_all_sort)

geneList = data_all_sort$log2FoldChange #???foldchange??????????????????????????????
names(geneList) <- data_all_sort$ENTREZID #??????????????????foldchange???????????????ENTREZID
head(geneList)

kegg_gmt <- read.gmt("D:/RNA-seq/downstream/gsea/msigdb.v7.5.1.entrez.gmt") #???gmt??????

gsea <- GSEA(geneList,
             TERM2GENE = kegg_gmt) #GSEA??????

dotplot(gsea)


gse.KEGG <- gseKEGG(geneList, 
                    organism = "hsa", # ??? hsa
                    pvalueCutoff = 1,
                    pAdjustMethod = "BH",) #?????????????????????
head(gse.KEGG)
#??????????????????????????????????????????
head(gse.KEGG)[1:10]


#head(gsea)
pdf(file="D:/RNA-seq/downstream/enrich_KEGG_GSEA.pdf",width = 10,height = 6)
gseaplot2(gse.KEGG,1)
dev.off()

### ??????????????????
gseaplot2(gse.KEGG,
          title = "Apelin signaling pathway",  #??????title
          "hsa04371", #??????hsa04740???????????????
          color="green", #????????????
          base_size = 15, #?????????????????????
          subplots = 1:3, #?????????2??????
          pvalue_table = T) # ??????p??? 

### ????????????GSEA??????
### ?????????????????????
gseaplot2(gse.KEGG,
          1:3, #?????????3???
          pvalue_table = T) # ??????p???

### ????????????????????????
gseaplot2(gse.KEGG,
          c("hsa04115"), #??????????????????
          pvalue_table = T) # ??????p???



gesa_result <- gse.KEGG

gesa_result_table <- gesa_result@result

