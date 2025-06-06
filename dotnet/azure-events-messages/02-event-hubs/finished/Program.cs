using Azure.Messaging.EventHubs;
using Azure.Messaging.EventHubs.Producer;
using Azure.Messaging.EventHubs.Consumer;
using System.Text;
using dotenv.net;

// Load environment variables from .env file and assign to variables
DotEnv.Load();
var envVars = DotEnv.Read();
string connectionString = envVars["EVENT_HUB_CONNECTION_STRING"];
string eventHubName = envVars["EVENT_HUB_NAME"];

// Check for empty connection string or event hub name
if (string.IsNullOrWhiteSpace(connectionString) || string.IsNullOrWhiteSpace(eventHubName))
{
    Console.WriteLine("Error: EVENT_HUB_CONNECTION_STRING and EVENT_HUB_NAME environment variables must be set.");
    return;
}

// Number of events to be sent to the event hub
int numOfEvents = 3;

// CREATE A PRODUCER CLIENT AND SEND EVENTS

// Create a producer client to send events to the event hub
EventHubProducerClient producerClient = new EventHubProducerClient(
    connectionString,
    eventHubName);

// Create a batch of events 
using EventDataBatch eventBatch = await producerClient.CreateBatchAsync();


// Adding a random number to the event body and sending the events. 
var random = new Random();
for (int i = 1; i <= numOfEvents; i++)
{
    int randomNumber = random.Next(1, 101); // 1 to 100 inclusive
    string eventBody = $"Event {randomNumber}";
    if (!eventBatch.TryAdd(new EventData(Encoding.UTF8.GetBytes(eventBody))))
    {
        // if it is too large for the batch
        throw new Exception($"Event {i} is too large for the batch and cannot be sent.");
    }
}

try
{
    // Use the producer client to send the batch of events to the event hub
    await producerClient.SendAsync(eventBatch);

    Console.WriteLine($"A batch of {numOfEvents} events has been published.");
    Console.WriteLine("Press Enter to retrieve and print the events...");
    Console.ReadLine();
}
finally
{
    await producerClient.DisposeAsync();
}

// CREATE A CONSUMER CLIENT AND RECEIVE EVENTS

// Create an EventHubConsumerClient
await using var consumerClient = new EventHubConsumerClient(
    EventHubConsumerClient.DefaultConsumerGroupName,
    connectionString,
    eventHubName);

Console.WriteLine("Retrieving all events from the hub...");

// Get total number of events in the hub by summing (last - first + 1) for all partitions
long totalEventCount = 0;
string[] partitionIds = await consumerClient.GetPartitionIdsAsync();
foreach (var partitionId in partitionIds)
{
    PartitionProperties properties = await consumerClient.GetPartitionPropertiesAsync(partitionId);
    if (properties.LastEnqueuedSequenceNumber >= properties.BeginningSequenceNumber)
    {
        totalEventCount += (properties.LastEnqueuedSequenceNumber - properties.BeginningSequenceNumber + 1);
    }
}

Console.WriteLine($"Total events in the hub: {totalEventCount}");

// Start retrieving events from the event hub and print to the console
int retrievedCount = 0;
await foreach (PartitionEvent partitionEvent in consumerClient.ReadEventsAsync(startReadingAtEarliestEvent: true))
{
    if (partitionEvent.Data != null)
    {
        string body = Encoding.UTF8.GetString(partitionEvent.Data.Body.ToArray());
        Console.WriteLine($"Retrieved event: {body}");
        retrievedCount++;
        if (retrievedCount >= totalEventCount)
        {
            Console.WriteLine("Done retrieving events. Press Enter to exit...");
            Console.ReadLine();
            return;
        }
    }
}