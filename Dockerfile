FROM eclipse-temurin:17-jre-jammy
# This expects the JAR to be in the target folder already
COPY target/*.jar app.jar
EXPOSE 8080
ENTRYPOINT ["java","-jar","/app.jar"]