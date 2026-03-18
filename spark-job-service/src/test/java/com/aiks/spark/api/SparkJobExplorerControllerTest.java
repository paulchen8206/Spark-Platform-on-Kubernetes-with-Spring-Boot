package com.aiks.spark.api;

import static org.junit.jupiter.api.Assertions.*;

import org.junit.jupiter.api.Test;
import org.mockito.Mockito;

class SparkJobExplorerControllerTest {

  @Test
  void testControllerInstantiation() {
    var taskExplorer = Mockito.mock(org.springframework.cloud.task.repository.TaskExplorer.class);
    var assembler = Mockito.mock(com.aiks.spark.util.pagination.PaginatedResourceAssembler.class);
    SparkJobExplorerController controller = new SparkJobExplorerController(taskExplorer, assembler);
    assertNotNull(controller);
  }
}
