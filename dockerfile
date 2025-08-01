FROM eclipse-temurin:17-jdk-alpine
ARG JAR_FILE=target/userservice-1.0.0.jar
COPY ${JAR_FILE} user-service.jar
EXPOSE 8080
ENTRYPOINT ["java","-jar","/user-service.jar"]

