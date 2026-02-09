package com.ksoot.spark.loganalysis;

import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import static org.junit.jupiter.api.Assertions.*;

class LogAnalysisJobTest {

    @Test
    void testInitRunsWithoutException() {
        LogAnalysisJob job = new LogAnalysisJob();
        job.hadoopDll = "dummy.dll";
        job.init();
        assertTrue(true); // Just verify init runs without exception
    }
}
