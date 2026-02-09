package com.ksoot.spark.api;

import org.junit.jupiter.api.Test;
import org.mockito.Mockito;
import static org.junit.jupiter.api.Assertions.*;

class SparkJobExplorerControllerTest {

    @Test
    void testControllerInstantiation() {
        var taskExplorer = Mockito.mock(org.springframework.cloud.task.repository.TaskExplorer.class);
        var assembler = Mockito.mock(com.ksoot.spark.util.pagination.PaginatedResourceAssembler.class);
        SparkJobExplorerController controller = new SparkJobExplorerController(taskExplorer, assembler);
        assertNotNull(controller);
    }
}
