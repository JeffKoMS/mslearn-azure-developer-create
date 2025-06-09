using Azure.Messaging.ServiceBus;
using Azure.Identity;
using System.Timers;


// TODO: Replace <YOUR-NAMESPACE> with your Service Bus namespace
string svcbusNameSpace = "svcbusns8061.servicebus.windows.net";
string queueName = "myqueue";


// ADD CODE TO CREATE A SERVICE BUS CLIENT

// Create a DefaultAzureCredentialOptions object to configure the DefaultAzureCredential
DefaultAzureCredentialOptions options = new()
{
    ExcludeEnvironmentCredential = true,
    ExcludeManagedIdentityCredential = true
};

// Create a Service Bus client using the namespace and DefaultAzureCredential
// The DefaultAzureCredential will use the Azure CLI credentials, so ensure you are logged in
ServiceBusClient client = new(svcbusNameSpace, new DefaultAzureCredential(options));


// ADD CODE TO SEND MESSAGES TO THE QUEUE

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
}

Console.WriteLine("Press any key to continue");
Console.ReadKey();


// ADD CODE TO PROCESS MESSAGES FROM THE QUEUE

// Create a processor that we can use to process the messages in the queue
ServiceBusProcessor processor = client.CreateProcessor(queueName, new ServiceBusProcessorOptions());

// Idle timeout in milliseconds, the idle timer will stop the processor if there are no more 
// messages in the queue to process
const int idleTimeoutMs = 3000;
System.Timers.Timer idleTimer = new(idleTimeoutMs);
idleTimer.Elapsed += async (s, e) =>
{
    Console.WriteLine($"No messages received for {idleTimeoutMs / 1000} seconds. Stopping processor...");
    await processor.StopProcessingAsync();
};

try
{
    // add handler to process messages
    processor.ProcessMessageAsync += MessageHandler;

    // add handler to process any errors
    processor.ProcessErrorAsync += ErrorHandler;

    // start processing 
    idleTimer.Start();
    await processor.StartProcessingAsync();

    Console.WriteLine($"Processor started. Will stop after {idleTimeoutMs / 1000} seconds of inactivity.");
    // Wait for the processor to stop
    while (processor.IsProcessing)
    {
        await Task.Delay(500);
    }
    idleTimer.Stop();
    Console.WriteLine("Stopped receiving messages");
}
finally
{
    // Dispose processor after use
    await processor.DisposeAsync();
}

// handle received messages
async Task MessageHandler(ProcessMessageEventArgs args)
{
    string body = args.Message.Body.ToString();
    Console.WriteLine($"Received: {body}");

    // Reset the idle timer on each message
    idleTimer.Stop();
    idleTimer.Start();

    // complete the message. message is deleted from the queue. 
    await args.CompleteMessageAsync(args.Message);
}

// handle any errors when receiving messages
Task ErrorHandler(ProcessErrorEventArgs args)
{
    Console.WriteLine(args.Exception.ToString());
    return Task.CompletedTask;
}


// Dispose client after use
await client.DisposeAsync();
