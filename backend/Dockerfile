# ── Stage 1: Build ─────────────────────────────────────────────
FROM maven:3.9.9-eclipse-temurin-21-alpine AS build

WORKDIR /build

# Copiar solo pom.xml primero para cachear dependencias
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Copiar el código fuente y compilar
COPY src ./src
RUN mvn clean package -DskipTests -B

# ── Stage 2: Runtime ────────────────────────────────────────────
FROM eclipse-temurin:21-jre-alpine

WORKDIR /app

# Crear usuario no-root
RUN addgroup -S spring && adduser -S spring -G spring
USER spring:spring

# Copiar el JAR desde el stage de build
COPY --from=build /build/target/*.jar app.jar

# Exponer puerto
EXPOSE 8080

# Health check
HEALTHCHECK --interval=10s --timeout=5s --retries=5 --start-period=30s \
  CMD wget --no-verbose --tries=1 --spider http://localhost:8080/actuator/health || exit 1

# Comando de entrada
ENTRYPOINT ["java", "-jar", "app.jar"]
CMD ["--spring.profiles.active=docker"]
