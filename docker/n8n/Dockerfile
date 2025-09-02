FROM n8nio/n8n:latest
USER root
RUN apk add --no-cache unpaper
RUN apk add --no-cache tesseract-ocr 
RUN apk add --no-cache tesseract-ocr-data-eng 
RUN apk add --no-cache ghostscript
RUN apk add --no-cache qpdf
RUN apk add --no-cache pngquant
RUN apk add --no-cache pandoc
RUN apk add --no-cache ocrmypdf
USER node