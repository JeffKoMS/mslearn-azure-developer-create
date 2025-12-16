using Microsoft.Azure.Cosmos;
using dotenv.net;

string databaseName = "myDatabase"; // Name of the database to create or use
string containerName = "myContainer"; // Name of the container to create or use

// Load environment variables from .env file
DotEnv.Load();
var envVars = DotEnv.Read();
string cosmosDbAccountUrl = envVars["DOCUMENT_ENDPOINT"];
string accountKey = envVars["ACCOUNT_KEY"];

if (string.IsNullOrEmpty(cosmosDbAccountUrl) || string.IsNullOrEmpty(accountKey))
{
    Console.WriteLine("Please set the DOCUMENT_ENDPOINT and ACCOUNT_KEY environment variables.");
    return;
}


// CREATE THE COSMOS DB CLIENT USING THE ACCOUNT URL AND KEY
CosmosClient client = new(
    accountEndpoint: cosmosDbAccountUrl,
    authKeyOrResourceToken: accountKey
);

try
{
    // CREATE A DATABASE IF IT DOESN'T ALREADY EXIST
    Database database = await client.CreateDatabaseIfNotExistsAsync(databaseName);
    Console.WriteLine($"Created or retrieved database: {database.Id}");

    // CREATE A CONTAINER WITH A SPECIFIED PARTITION KEY
    Container container = await database.CreateContainerIfNotExistsAsync(
        id: containerName,
        partitionKeyPath: "/id"
    );
    Console.WriteLine($"Created or retrieved container: {container.Id}");

    // DEFINE A TYPED ITEM (PRODUCT) TO ADD TO THE CONTAINER
    Product newItem = new Product
    {
        id = Guid.NewGuid().ToString(), // Generate a unique ID for the product
        name = "Sample Item",
        description = "This is a sample item in my Azure Cosmos DB exercise."
    };

    // ADD THE ITEM TO THE CONTAINER
    // The partition key ensures the item is stored in the correct partition
    ItemResponse<Product> createResponse = await container.CreateItemAsync(
        item: newItem,
        partitionKey: new PartitionKey(newItem.id)
    );

    Console.WriteLine($"Created item with ID: {createResponse.Resource.id}");
    Console.WriteLine($"Request charge: {createResponse.RequestCharge} RUs");
}
catch (CosmosException ex)
{
    // Handle Cosmos DB-specific exceptions
    // Log the status code and error message for debugging
    Console.WriteLine($"Cosmos DB Error: {ex.StatusCode} - {ex.Message}");
}
catch (Exception ex)
{
    // Handle general exceptions
    // Log the error message for debugging
    Console.WriteLine($"Error: {ex.Message}");
}

// This class represents a product in the Cosmos DB container
public class Product
{
    public string? id { get; set; }
    public string? name { get; set; }
    public string? description { get; set; }
}