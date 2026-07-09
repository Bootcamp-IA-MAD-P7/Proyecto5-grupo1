package com.sentilife;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.ActiveProfiles;

@SpringBootTest
@ActiveProfiles("test")
class SentiLifeApplicationTests {

    @Test
    void contextLoads() {
        // Verifica que el contexto de Spring arranca sin errores
    }
}
