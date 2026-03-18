package com.aiks.spark.sales;

import static org.junit.jupiter.api.Assertions.*;

import org.junit.jupiter.api.Test;
import org.mockito.Mockito;

class SalesReportJobTest {

  @Test
  void testInitCallsPopulateData() {
    DataPopulator mockPopulator = Mockito.mock(DataPopulator.class);
    SalesReportJob job = new SalesReportJob();
    job.dataPopulator = mockPopulator;
    job.hadoopDll = "dummy.dll";
    job.init();
    Mockito.verify(mockPopulator).populateData();
  }
}
