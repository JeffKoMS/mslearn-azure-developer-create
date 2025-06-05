using Azure.Messaging.EventHubs;
using Azure.Messaging.EventHubs.Producer;
using Azure.Messaging.EventHubs.Consumer;
using System.Text;
using dotenv.net;

// Load environment variables from .env file and assign
DotEnv.Load();
var envVars = DotEnv.Read();

string connectionString = envVars["EVENT_HUB_CONNECTION_STRING"];
string eventHubName = envVars["EVENT_HUB_NAME"];

// Add check for empty connection string or event hub name
if (string.IsNullOrWhiteSpace(connectionString) || string.IsNullOrWhiteSpace(eventHubName))
{
    Console.WriteLine("Error: EVENT_HUB_CONNECTION_STRING and EVENT_HUB_NAME environment variables must be set.");
    return;
}

// number of events to be sent to the event hub
int numOfEvents = 5;

// Create a producer client to send events to the event hub
EventHubProducerClient producerClient = new EventHubProducerClient(
    connectionString,
    eventHubName);

// Create a batch of events 
using EventDataBatch eventBatch = await producerClient.CreateBatchAsync();

for (int i = 1; i <= numOfEvents; i++)
{
    if (!eventBatch.TryAdd(new EventData(Encoding.UTF8.GetBytes($"Event {i}"))))
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
    Console.WriteLine("Check the Azure portal to see verify events in the Event Hub.");
    Console.WriteLine("When finished, press Enter to receive and print the events...");
    Console.ReadLine();
}
finally
{
    await producerClient.DisposeAsync();
}

// Receive and print events using EventHubConsumerClient
await using var consumerClient = new EventHubConsumerClient(
    EventHubConsumerClient.DefaultConsumerGroupName,
    connectionString,
    eventHubName);

Console.WriteLine("Receiving events from the beginning of the stream...");

int receivedCount = 0;
await foreach (PartitionEvent partitionEvent in consumerClient.ReadEventsAsync(startReadingAtEarliestEvent: true))
{
    if (partitionEvent.Data != null)
    {
        string body = Encoding.UTF8.GetString(partitionEvent.Data.Body.ToArray());
        Console.WriteLine($"Received event: {body}");
        receivedCount++;
        if (receivedCount >= numOfEvents)
        {
            Console.WriteLine("Done receiving events. Press Enter to exit...");
            Console.ReadLine();
            return;
        }
    }
}