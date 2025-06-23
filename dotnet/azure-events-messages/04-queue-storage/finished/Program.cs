using Azure;
using Azure.Identity;
using Azure.Storage.Queues;
using Azure.Storage.Queues.Models;
using System;
using System.Threading.Tasks;

// Create a unique name for the queue
// TODO: Replace the <YOUR-STORAGE-ACCT-NAME> placeholder 
string queueName = "myqueue-" + Guid.NewGuid().ToString();
string storageAccountName = "<YOUR-STORAGE-ACCT-NAME>";

// ADD CODE TO CREATE A QUEUE CLIENT AND CREATE A QUEUE

// Create a DefaultAzureCredentialOptions object to exclude certain credentials
DefaultAzureCredentialOptions options = new()
{
    ExcludeEnvironmentCredential = true,
    ExcludeManagedIdentityCredential = true
};

// Instantiate a QueueClient to create and interact with the queue
QueueClient queueClient = new QueueClient(
    new Uri($"https://{storageAccountName}.queue.core.windows.net/{queueName}"),
    new DefaultAzureCredential(options));

Console.WriteLine($"Creating queue: {queueName}");

// Create the queue
await queueClient.CreateAsync();

Console.WriteLine("Queue created, press Enter to add messages to the queue...");
Console.ReadLine();

// ADD CODE TO SEND AND LIST MESSAGES

// Send several messages to the queue with the SendMessageAsync method.
await queueClient.SendMessageAsync("Message 1");
await queueClient.SendMessageAsync("Message 2");

// Send a message and save the receipt for later use
SendReceipt receipt = await queueClient.SendMessageAsync("Message 3");

Console.WriteLine("Messages added to the queue. Press Enter to peek at the messages...");
Console.ReadLine();

// Peeking messages lets you view the messages without removing them from the queue.

foreach (var message in (await queueClient.PeekMessagesAsync(maxMessages: 10)).Value)
{
    Console.WriteLine($"Message: {message.MessageText}");
}

Console.WriteLine("\nPress Enter to update a message in the queue...");
Console.ReadLine();

// ADD CODE TO UPDATE A MESSAGE AND LIST MESSAGES

// Update a message with the UpdateMessageAsync method and the saved receipt
await queueClient.UpdateMessageAsync(receipt.MessageId, receipt.PopReceipt, "Message 3 has been updated");

Console.WriteLine("Message three updated. Press Enter to peek at the messages again...");
Console.ReadLine();


// Peek messages from the queue to compare updated content
foreach (var message in (await queueClient.PeekMessagesAsync(maxMessages: 10)).Value)
{
    Console.WriteLine($"Message: {message.MessageText}");
}

Console.WriteLine("\nPress Enter to delete messages from the queue...");
Console.ReadLine();

// ADD CODE TO DELETE MESSAGES AND THE QUEUE

// Delete messages from the queue with the DeleteMessagesAsync method.
foreach (var message in (await queueClient.ReceiveMessagesAsync(maxMessages: 10)).Value)
{
    // "Process" the message
    Console.WriteLine($"Deleting message: {message.MessageText}");

    // Let the service know we're finished with the message and it can be safely deleted.
    await queueClient.DeleteMessageAsync(message.MessageId, message.PopReceipt);
}
Console.WriteLine("Messages deleted from the queue.");
Console.WriteLine("\nPress Enter key to delete the queue...");
Console.ReadLine();

// Delete the queue with the DeleteAsync method.
Console.WriteLine($"Deleting queue: {queueClient.Name}");
await queueClient.DeleteAsync();

Console.WriteLine("Done");