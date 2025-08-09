package com.example.app;

import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import java.util.Map;

@RestController
public class ApiController {

    private final CounterService counterService;

    public ApiController(CounterService counterService) {
        this.counterService = counterService;
    }

    @GetMapping("/healthcheck")
    public ResponseEntity<Map<String, Object>> healthcheck() {
        return ResponseEntity.ok(Map.of(
                "status", "UP"
        ));
    }

    @GetMapping("/contador")
    public ResponseEntity<Map<String, Object>> contador() {
        long value = counterService.incrementAndGet();
        return ResponseEntity.ok(Map.of(
                "contador", value
        ));
    }
}
