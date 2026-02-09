package com.ksoot.spark.loganalysis;

import static org.junit.jupiter.api.Assertions.*;

import org.junit.jupiter.api.Test;

class LogAnalysisJobTest {

  @Test
  void testInitRunsWithoutException() {
    LogAnalysisJob job = new LogAnalysisJob();
    job.hadoopDll = "dummy.dll";
    job.init();
    assertTrue(true); // Just verify init runs without exception
  }
}
