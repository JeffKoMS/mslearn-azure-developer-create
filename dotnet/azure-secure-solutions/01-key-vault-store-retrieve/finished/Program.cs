
using Azure.Identity;
using Azure.Security.KeyVault.Secrets;

// Replace YOUR-KEYVAULT-NAME with your actual Key Vault name
string KeyVaultUrl = "https://YOUR-KEYVAULT-NAME.vault.azure.net/";

// ADD CODE TO CREATE A CLIENT

// Configure authentication options for connecting to Azure Key Vault
DefaultAzureCredentialOptions options = new()
{
    ExcludeEnvironmentCredential = true,
    ExcludeManagedIdentityCredential = true
};

// Create the Key Vault client using the URL and authentication credentials
var client = new SecretClient(new Uri(KeyVaultUrl), new DefaultAzureCredential(options));

// ADD CODE TO CREATE A MENU SYSTEM

// Main application loop - continues until user types 'quit'
while (true)
{
    // Display menu options to the user
    Console.Clear();
    Console.WriteLine("\nPlease select an option:");
    Console.WriteLine("1. Create a new secret");
    Console.WriteLine("2. List all secrets");
    Console.WriteLine("Type 'quit' to exit");
    Console.Write("Enter your choice: ");

    // Read user input and convert to lowercase for easier comparison
    string? input = Console.ReadLine()?.Trim().ToLower();
    
    // Check if user wants to exit the application
    if (input == "quit")
    {
        Console.WriteLine("Goodbye!");
        break;
    }

    // Process the user's menu selection
    switch (input)
    {
        case "1":
            // Call the method to create a new secret
            await CreateSecretAsync(client);
            break;
        case "2":
            // Call the method to list all existing secrets
            await ListSecretsAsync(client);
            break;
        default:
            // Handle invalid input
            Console.WriteLine("Invalid option. Please enter 1, 2, or 'quit'.");
            break;
    }
}

// ADD CODE TO CREATE A SECRET

async Task CreateSecretAsync(SecretClient client)
{
    try
    {
        Console.Clear();
        Console.WriteLine("\nCreating a new secret...");
        
        // Get the secret name from user input
        Console.Write("Enter secret name: ");
        string? secretName = Console.ReadLine()?.Trim();

        // Validate that the secret name is not empty
        if (string.IsNullOrEmpty(secretName))
        {
            Console.WriteLine("Secret name cannot be empty.");
            return;
        }
        
        // Get the secret value from user input
        Console.Write("Enter secret value: ");
        string? secretValue = Console.ReadLine()?.Trim();

        // Validate that the secret value is not empty
        if (string.IsNullOrEmpty(secretValue))
        {
            Console.WriteLine("Secret value cannot be empty.");
            return;
        }

        // Create a new KeyVaultSecret object with the provided name and value
        var secret = new KeyVaultSecret(secretName, secretValue);
        
        // Store the secret in Azure Key Vault
        await client.SetSecretAsync(secret);

        Console.WriteLine($"Secret '{secretName}' created successfully!");
        Console.WriteLine("Press Enter to continue...");
        Console.ReadLine();
    }
    catch (Exception ex)
    {
        // Handle any errors that occur during secret creation
        Console.WriteLine($"Error creating secret: {ex.Message}");
    }
}

// ADD CODE TO LIST SECRETS

async Task ListSecretsAsync(SecretClient client)
{
    try
    {
        Console.Clear();
        Console.WriteLine("Listing all secrets in the Key Vault...");
        Console.WriteLine("----------------------------------------");

        // Get an async enumerable of all secret properties in the Key Vault
        var secretProperties = client.GetPropertiesOfSecretsAsync();
        bool hasSecrets = false;

        // Iterate through each secret property to retrieve full secret details
        await foreach (var secretProperty in secretProperties)
        {
            hasSecrets = true;
            try
            {
                // Retrieve the actual secret value and metadata using the secret name
                var secret = await client.GetSecretAsync(secretProperty.Name);
                
                // Display the secret information to the console
                Console.WriteLine($"Name: {secret.Value.Name}");
                Console.WriteLine($"Value: {secret.Value.Value}");
                Console.WriteLine($"Created: {secret.Value.Properties.CreatedOn}");
                Console.WriteLine("----------------------------------------");
            }
            catch (Exception ex)
            {
                // Handle errors for individual secrets (e.g., access denied, secret not found)
                Console.WriteLine($"Error retrieving secret '{secretProperty.Name}': {ex.Message}");
                Console.WriteLine("----------------------------------------");
            }
        }

        // Inform user if no secrets were found in the Key Vault
        if (!hasSecrets)
        {
            Console.WriteLine("No secrets found in the Key Vault.");
        }
    }
    catch (Exception ex)
    {
        // Handle general errors that occur during the listing operation
        Console.WriteLine($"Error listing secrets: {ex.Message}");
    
    }
    Console.WriteLine("Press Enter to continue...");
    Console.ReadLine();
}
