using Azure.Messaging.ServiceBus;
using Azure.Identity;


// TODO: Replace <YOUR-NAMESPACE> with your Service Bus namespace
string svcbusNameSpace = "svcbusns8061.servicebus.windows.net";
string queueName = "myQueue";

// Create a DefaultAzureCredentialOptions object to configure the DefaultAzureCredential
DefaultAzureCredentialOptions options = new()
{
    ExcludeEnvironmentCredential = true,
    ExcludeManagedIdentityCredential = true
};

// 

// Create a Service Bus client using the namespace and DefaultAzureCredential
// The DefaultAzureCredential will use the Azure CLI credentials, so ensure you are logged in
ServiceBusClient client = new(svcbusNameSpace, new DefaultAzureCredential(options));

// Create a sender for the specified queue
ServiceBusSender sender = client.CreateSender(queueName);

// create a batch 
using ServiceBusMessageBatch messageBatch = await sender.CreateMessageBatchAsync();

// number of messages to be sent to the queue
const int numOfMessages = 3;

for (int i = 1; i <= numOfMessages; i++)
{
    // try adding a message to the batch
    if (!messageBatch.TryAddMessage(new ServiceBusMessage($"Message {i}")))
    {
        // if it is too large for the batch
        throw new Exception($"The message {i} is too large to fit in the batch.");
    }
}

try
{
    // Use the producer client to send the batch of messages to the Service Bus queue
    await sender.SendMessagesAsync(messageBatch);
    Console.WriteLine($"A batch of {numOfMessages} messages has been published to the queue.");
}
finally
{
    // Calling DisposeAsync on client types is required to ensure that network
    // resources and other unmanaged objects are properly cleaned up.
    await sender.DisposeAsync();
    await client.DisposeAsync();
}

Console.WriteLine("Press any key to end the application");
Console.ReadKey();