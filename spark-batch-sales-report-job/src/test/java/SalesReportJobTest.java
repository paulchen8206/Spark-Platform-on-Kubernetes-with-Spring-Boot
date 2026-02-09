package com.ksoot.spark.sales;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;

import static org.junit.jupiter.api.Assertions.*;

@SpringBootTest(classes = com.ksoot.spark.sales.SalesReportJob.class)
class SalesReportJobTest {

    @Test
    void contextLoads() {
        assertTrue(true);
    }
}
