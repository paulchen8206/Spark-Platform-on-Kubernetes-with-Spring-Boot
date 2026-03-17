package com.ksoot.spark.sales.pipeline;

import org.apache.spark.sql.Dataset;
import org.apache.spark.sql.Row;

public abstract class SalesReportPipelineTemplate {

  public final Dataset<Row> run() {
    Dataset<Row> salesDataset = this.loadSales();
    Dataset<Row> aggregatedSales = this.aggregateSales(salesDataset);
    Dataset<Row> productsDataset = this.loadProducts();
    Dataset<Row> reportDataset = this.buildReport(aggregatedSales, productsDataset);
    this.persist(reportDataset);
    return reportDataset;
  }

  protected abstract Dataset<Row> loadSales();

  protected abstract Dataset<Row> aggregateSales(Dataset<Row> salesDataset);

  protected abstract Dataset<Row> loadProducts();

  protected abstract Dataset<Row> buildReport(
      Dataset<Row> aggregatedSales, Dataset<Row> productsDataset);

  protected abstract void persist(Dataset<Row> reportDataset);
}
