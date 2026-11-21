# Stage 1: Build the WAR file using Maven + JDK 17
FROM maven:3.9-eclipse-temurin-17 AS builder
WORKDIR /app

# Copy POM files first to leverage Docker layer caching
COPY pom.xml .
COPY server/pom.xml ./server/
COPY webapp/pom.xml ./webapp/

# Copy source code and package the WAR (tests already ran in Jenkins)
COPY server/src ./server/src
COPY webapp/src ./webapp/src
RUN mvn clean package -DskipTests

# Stage 2: Lightweight Tomcat runtime image (JRE only, no Maven/JDK)
FROM tomcat:9.0-jre17-temurin-jammy

# Remove default Tomcat webapps to reduce attack surface
RUN rm -rf /usr/local/tomcat/webapps/*

# Copy only the built WAR from the builder stage
# Use ROOT.war to serve at http://<IP>:30080/ or webapp.war for /webapp/
COPY --from=builder /app/webapp/target/webapp.war /usr/local/tomcat/webapps/webapp.war

EXPOSE 8080
CMD ["catalina.sh", "run"]
