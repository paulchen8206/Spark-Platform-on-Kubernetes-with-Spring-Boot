package com.aiks.spark.sales;

import static org.apache.spark.sql.functions.col;
import static org.apache.spark.sql.functions.sum;

import com.aiks.spark.common.connector.ArangoConnector;
import com.aiks.spark.common.connector.MongoConnector;
import com.aiks.spark.common.util.SparkUtils;
import com.aiks.spark.sales.conf.JobProperties;
import com.aiks.spark.sales.pipeline.SalesReportPipelineTemplate;
import lombok.extern.slf4j.Slf4j;
import org.apache.spark.sql.Dataset;
import org.apache.spark.sql.Row;
import org.apache.spark.sql.SparkSession;
import org.apache.spark.sql.types.DataTypes;
import org.springframework.stereotype.Component;

@Component
@Slf4j
public class SparkPipelineExecutor {

  private final SalesReportPipelineTemplate pipelineTemplate;

  public SparkPipelineExecutor(
      final SparkSession sparkSession,
      final JobProperties jobProperties,
      final MongoConnector mongoConnector,
      final ArangoConnector arangoConnector) {
    this.jobProperties = jobProperties;
    this.mongoConnector = mongoConnector;
    this.arangoConnector = arangoConnector;
    this.pipelineTemplate =
        new SalesReportPipelineTemplate() {
          @Override
          protected Dataset<Row> loadSales() {
            Dataset<Row> salesDataset = SparkPipelineExecutor.this.mongoConnector.read("sales");
            SparkUtils.logDataset("Sales Dataset", salesDataset);
            return salesDataset;
          }

          @Override
          protected Dataset<Row> aggregateSales(final Dataset<Row> salesDataset) {
            final String statementMonth =
                SparkPipelineExecutor.this.jobProperties.getMonth().toString();
            return salesDataset
                .filter(col("timestamp").startsWith(statementMonth))
                .withColumn("date", col("timestamp").substr(0, 10))
                .withColumn(
                    "sale_amount",
                    col("price")
                        .cast(DataTypes.DoubleType)
                        .multiply(col("quantity").cast(DataTypes.IntegerType)))
                .groupBy("product_id", "date")
                .agg(sum("sale_amount").alias("daily_sale_amount"));
          }

          @Override
          protected Dataset<Row> loadProducts() {
            Dataset<Row> productsDataset =
                SparkPipelineExecutor.this.arangoConnector.readAll("products");
            SparkUtils.logDataset("Products Dataset", productsDataset);
            return productsDataset;
          }

          @Override
          protected Dataset<Row> buildReport(
              final Dataset<Row> aggregatedSales, final Dataset<Row> productsDataset) {
            Dataset<Row> monthlySalesReport =
                aggregatedSales
                    .join(
                        productsDataset,
                        aggregatedSales
                            .col("product_id")
                            .equalTo(productsDataset.col("product_id")))
                    .select(
                        productsDataset.col("product_name").as("product"),
                        aggregatedSales.col("date"),
                        aggregatedSales.col("daily_sale_amount").alias("sale"))
                    .orderBy(col("product_name"), col("date"));
            SparkUtils.logDataset("Sales report", monthlySalesReport);
            return monthlySalesReport;
          }

          @Override
          protected void persist(final Dataset<Row> reportDataset) {
            final String statementMonth =
                SparkPipelineExecutor.this.jobProperties.getMonth().toString();
            final String salesReportCollection = "sales_report_" + statementMonth.replace('-', '_');
            SparkPipelineExecutor.this.arangoConnector.write(reportDataset, salesReportCollection);
          }
        };
  }

  private final JobProperties jobProperties;

  private final MongoConnector mongoConnector;

  private final ArangoConnector arangoConnector;

  public void execute() {
    log.info("Generating Sales report for month: {}", this.jobProperties.getMonth());
    this.pipelineTemplate.run();
    // this.fileConnector.write(monthlySalesReport); // For testing
  }
}
