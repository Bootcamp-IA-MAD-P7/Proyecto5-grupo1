---
marp: true
theme: default
paginate: true
title: SentiLife — Presentación de Negocio
---

# SentiLife
## Detección inteligente de caídas para personas mayores

**Factoría F5 Madrid · Grupo 1 · Julio 2026**

---

## El problema

- Las caídas son la **principal causa de hospitalización** en mayores
- El tiempo entre caída y asistencia determina la gravedad de las consecuencias
- Los cuidadores no pueden vigilar 24/7
- Los falsos positivos generan **fatiga de alerta** y pérdida de confianza

---

## Nuestra solución

**SentiLife** monitoriza en tiempo real a la persona mayor mediante el móvil:

1. Captura movimiento (acelerómetro + giroscopio)
2. Detecta caídas con **Inteligencia Artificial**
3. Alerta al **cuidador en segundos** (push notification)
4. Aprende del feedback del cuidador para **mejorar el modelo**

---

## ¿Cómo funciona?

```
Persona mayor (móvil)  →  Detección IA  →  Alerta al cuidador
        ↓                      ↓                    ↓
   Consentimiento         < 5 segundos        Confirmar / Descartar
```

- La persona da **consentimiento explícito** antes de monitorizar
- El cuidador recibe push y puede **confirmar o descartar** la alerta
- El feedback alimenta el **reentrenamiento automático** del modelo

---

## Perfiles de usuario

| Rol | Quién es | Qué hace |
|---|---|---|
| **Persona monitorizada** | Mayor con móvil | Empareja dispositivo, acepta consentimiento, monitoriza |
| **Cuidador** | Familiar o profesional | Registra persona, recibe alertas, da feedback |
| **Área IT** | Administrador técnico | Exporta datos, gestiona usuarios, **reentrena modelos** |

---

## Resultados clave

| Métrica | Valor | Significado |
|---|---|---|
| Recall de caídas | **89%** | Detectamos 9 de cada 10 caídas |
| Latencia alerta | **< 1 s** | El cuidador sabe casi al instante |
| Falsos positivos (ADL) | **0/3** | Actividad normal no genera alertas |
| Overfitting | **< 5%** | Modelo generaliza, no memoriza |

---

## Diferenciadores

- **Tiempo real**: predicción en milisegundos, no en batch
- **Privacidad**: consentimiento GDPR, supresión demostrada, datos seudonimizados
- **Mejora continua**: ciclo MLOps — el modelo se reentrena con feedback real
- **Observabilidad**: dashboards Grafana para el equipo técnico
- **Evidencia académica**: entrenado con SisFall (dataset validado científicamente)

---

## Demo en vivo (Factoría)

1. Persona monitorizada con móvil → caída simulada
2. Cuidador recibe **push < 5 s**
3. IT lanza **reentrenamiento** desde la app
4. Grafana muestra **drift** y **A/B testing**

---

## Roadmap post-Factoría

| Fase | Objetivo |
|---|---|
| Corto plazo | Validación con mayores reales, reducir sesgo de edad |
| Medio plazo | Integración wearables, ampliar señales (FC, temperatura) |
| Largo plazo | Predicción preventiva de riesgo de caída |

---

## Equipo

**SentiLife · Grupo 1 · Factoría F5 Madrid**

Stack: Flutter · Spring Boot · FastAPI · PostgreSQL · RabbitMQ · Prometheus · Grafana

Repositorio: GitHub · Documentación SDD completa en `.specify/specs/factoria/`

---

# Gracias
## ¿Preguntas?
