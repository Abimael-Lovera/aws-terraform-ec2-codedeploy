package com.example.app;

import java.util.concurrent.atomic.AtomicLong;
import org.springframework.stereotype.Service;

@Service
public class CounterService {
    private final AtomicLong counter = new AtomicLong();

    public long incrementAndGet() {
        return counter.incrementAndGet();
    }

    public long get() {
        return counter.get();
    }
}
