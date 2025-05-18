using dotenv.net; 
using Azure.Messaging.EventGrid; 

// Load environment variables from .env file
DotEnv.Load();
var envVars = DotEnv.Read();

// Start the asynchronous process to send an Event Grid event
ProcessAsync().GetAwaiter().GetResult();

async Task ProcessAsync()
{
    // Retrieve Event Grid topic endpoint and access key from environment variables
    var topicEndpoint = envVars["TOPIC_ENDPOINT"];
    var topicKey = envVars["TOPIC_ACCESS_KEY"];
    
    // Check if the required environment variables are set
    if (string.IsNullOrEmpty(topicEndpoint) || string.IsNullOrEmpty(topicKey))
    {
        Console.WriteLine("Please set TOPIC_ENDPOINT and TOPIC_ACCESS_KEY in your .env file.");
        return;
    }

    // Create an EventGridPublisherClient to send events to the specified topic
    EventGridPublisherClient client = new EventGridPublisherClient
        (new Uri(topicEndpoint),
        new Azure.AzureKeyCredential(topicKey));

    // Create a new EventGridEvent with sample data
    var eventGridEvent = new EventGridEvent(
        subject: "ExampleSubject",
        eventType: "ExampleEventType",
        dataVersion: "1.0",
        data: new { Message = "Hello, Event Grid!" }
    );

    // Send the event to Azure Event Grid
    await client.SendEventAsync(eventGridEvent);
    Console.WriteLine("Event sent successfully.");
}
