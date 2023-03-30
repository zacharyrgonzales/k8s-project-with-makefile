FROM nginx:alpine
LABEL maintainer="Zachary Gonzales <zacharyrgonzales@gmail.com>"

COPY website /website
COPY nginx.conf /etc/nginx/nginx.conf

EXPOSE 80
