package com.aiks.spark.sales;

import com.aiks.spark.common.config.properties.ArangoOptions;
import com.aiks.spark.common.config.properties.ConnectorProperties;
import com.arangodb.ArangoCollection;
import com.arangodb.ArangoDB;
import com.arangodb.ArangoDatabase;
import com.mongodb.client.MongoCollection;
import java.time.*;
import java.util.*;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import net.datafaker.Faker;
import org.apache.commons.collections4.CollectionUtils;
import org.bson.Document;
import org.bson.types.ObjectId;
import org.springframework.data.domain.Sort;
import org.springframework.data.mongodb.core.MongoOperations;
import org.springframework.data.mongodb.core.index.Index;
import org.springframework.data.mongodb.core.query.Query;
import org.springframework.stereotype.Component;

@Component
@Slf4j
@RequiredArgsConstructor
public class DataPopulator {

  private static final Faker faker =
      new Faker(new Locale.Builder().setLanguage("en").setRegion("US").build());
  private static final String[] products = {
    "1001", "1002", "1003", "1004", "1005", "1006", "1007", "1008", "1009", "1010"
  };

  // Number of records to be created in a batch
  private static final int BATCH_SIZE = 1000;

  private static final int NO_OF_MONTHS_TO_GENERATE_DATA_FOR = 12;

  private static final String PRODUCTS_COLLECTION = "products";
  private static final String SALES_COLLECTION = "sales";

  private final MongoOperations mongoOperations;

  private final ConnectorProperties connectorProperties;

  public void populateData() {
    this.createProductsData();
    this.createSalesSchema();
    this.createSalesData();
  }

  private void createProductsData() {
    log.info("Ensuring ArangoDB product reference data");
    final ArangoOptions arangoOptions = this.connectorProperties.getArangoOptions();
    final ArangoDB arangoDB = this.arangoDB(arangoOptions);
    try {
      if (!arangodbDatabase(arangoDB, arangoOptions).exists()) {
        arangoDB.createDatabase(arangoOptions.getDatabase());
        log.info("Created ArangoDB database: {}", arangoOptions.getDatabase());
      }

      final ArangoDatabase arangoDatabase = arangodbDatabase(arangoDB, arangoOptions);
      final ArangoCollection productsCollection = arangoDatabase.collection(PRODUCTS_COLLECTION);
      if (!productsCollection.exists()) {
        arangoDatabase.createCollection(PRODUCTS_COLLECTION);
        log.info("Created ArangoDB collection: {}", PRODUCTS_COLLECTION);
      }

      final ArangoCollection existingProductsCollection =
          arangoDatabase.collection(PRODUCTS_COLLECTION);
      final long existingCount =
          Optional.ofNullable(existingProductsCollection.count().getCount()).orElse(0L);
      if (existingCount == 0L) {
        existingProductsCollection.insertDocuments(this.productsData());
        log.info(
            "Inserted {} product reference documents into {}",
            products.length,
            PRODUCTS_COLLECTION);
      } else {
        log.info(
            "Product reference data already exists in {} with {} documents",
            PRODUCTS_COLLECTION,
            existingCount);
      }
    } finally {
      arangoDB.shutdown();
    }
  }

  private ArangoDB arangoDB(final ArangoOptions arangoOptions) {
    final ArangoDB.Builder builder =
        new ArangoDB.Builder()
            .user(arangoOptions.getUsername())
            .password(arangoOptions.getPassword())
            .useSsl(arangoOptions.isSslEnabled());

    for (String endpoint : arangoOptions.getEndpoints()) {
      final String[] hostParts =
          endpoint.trim().replace("http://", "").replace("https://", "").split(":", 2);
      final String host = hostParts[0];
      final int port = hostParts.length > 1 ? Integer.parseInt(hostParts[1]) : 8529;
      builder.host(host, port);
    }
    return builder.build();
  }

  private ArangoDatabase arangodbDatabase(
      final ArangoDB arangoDB, final ArangoOptions arangoOptions) {
    return arangoDB.db(arangoOptions.getDatabase());
  }

  private List<Map<String, Object>> productsData() {
    return List.of(
        this.productDocument("1001", "TV"),
        this.productDocument("1002", "Mobile"),
        this.productDocument("1003", "Table"),
        this.productDocument("1004", "Chair"),
        this.productDocument("1005", "Sofa"),
        this.productDocument("1006", "AC"),
        this.productDocument("1007", "Bed"),
        this.productDocument("1008", "Charger"),
        this.productDocument("1009", "Laptop"),
        this.productDocument("1010", "Tablet"));
  }

  private Map<String, Object> productDocument(final String productId, final String productName) {
    final Map<String, Object> document = new LinkedHashMap<>();
    document.put("_key", productId);
    document.put("product_id", productId);
    document.put("product_name", productName);
    return document;
  }

  private void createSalesSchema() {
    log.info("Creating Sales collection Schema");
    if (!this.mongoOperations.collectionExists(SALES_COLLECTION)) {
      this.mongoOperations.createCollection(SALES_COLLECTION);
      log.info("Created Collection: {}", SALES_COLLECTION);
      final Index indexTimestamp =
          new Index().named("idx_timestamp").on("timestamp", Sort.Direction.ASC);
      this.mongoOperations.indexOps(SALES_COLLECTION).ensureIndex(indexTimestamp);
    } else {
      log.info("Collection already exists: {}", SALES_COLLECTION);
    }
  }

  private void createSalesData() {
    final MongoCollection<Document> salesCollection =
        this.mongoOperations.getCollection(SALES_COLLECTION);
    final LocalDate yesterday = LocalDate.now().minusDays(1);
    if (salesCollection.countDocuments() > 0) {
      final LocalDate maxDate = this.getMaxSaleDate();
      if (yesterday.isAfter(maxDate)) {
        log.info(
            "Sales data already exists till date: {}. Creating sales data till date: {}",
            maxDate,
            yesterday);
        this.createSalesDataInDateRange(salesCollection, maxDate, yesterday);
      } else {
        log.info("Sales data already upto date");
      }
    } else {
      log.info(
          "Sales data not found. Creating Sales data for last {} months",
          NO_OF_MONTHS_TO_GENERATE_DATA_FOR);
      final LocalDate fromDate = yesterday.minusMonths(NO_OF_MONTHS_TO_GENERATE_DATA_FOR);

      this.createSalesDataInDateRange(salesCollection, fromDate, yesterday);
    }
  }

  public LocalDate getMaxSaleDate() {
    Query query = new Query();
    query.with(Sort.by(Sort.Direction.DESC, "timestamp"));
    query.limit(1);
    Document document = this.mongoOperations.findOne(query, Document.class, SALES_COLLECTION);
    Date maxTimestamp = document.get("timestamp", Date.class);
    return maxTimestamp.toInstant().atZone(ZoneId.systemDefault()).toLocalDate();
  }

  private void createSalesDataInDateRange(
      final MongoCollection<Document> salesCollection,
      final LocalDate fromDate,
      LocalDate tillDate) {
    int recordCount = 0;
    final List<Document> sales = new ArrayList<>(BATCH_SIZE);
    for (LocalDate date = fromDate; !date.isAfter(tillDate); date = date.plusDays(1)) {

      int salesPerDay = faker.number().numberBetween(1, 11);
      for (int j = 0; j < salesPerDay; j++) {

        final String transactionId = faker.internet().uuid();
        final long time = faker.time().between(LocalTime.MIN, LocalTime.MAX);
        final LocalDateTime timestamp = LocalDateTime.of(date, LocalTime.ofNanoOfDay(time));
        final String productId = new Faker().options().option(products);
        final int quantity = faker.number().numberBetween(1, 6);
        final double price = faker.number().randomDouble(2, 10, 1000);

        final Document sale = new Document("_id", new ObjectId());
        sale.append("transaction_id", transactionId)
            .append("timestamp", timestamp)
            .append("product_id", productId)
            .append("quantity", quantity)
            .append("price", price);
        sales.add(sale);

        recordCount++;
        if (recordCount % BATCH_SIZE == 0) {
          salesCollection.insertMany(sales);
          sales.clear();
          log.info("Created {} Sales transactions, processed for date: {}", recordCount, date);
        }
      }
    }

    if (CollectionUtils.isNotEmpty(sales)) {
      salesCollection.insertMany(sales);
      sales.clear();
    }
    log.info("Created {} Sales transactions", recordCount);
  }
}
