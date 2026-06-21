IF OBJECT_ID(N'[__EFMigrationsHistory]') IS NULL
BEGIN
    CREATE TABLE [__EFMigrationsHistory] (
        [MigrationId] nvarchar(150) NOT NULL,
        [ProductVersion] nvarchar(32) NOT NULL,
        CONSTRAINT [PK___EFMigrationsHistory] PRIMARY KEY ([MigrationId])
    );
END;
GO

BEGIN TRANSACTION;
GO

CREATE TABLE [Courts] (
    [Id] int NOT NULL IDENTITY,
    [Name] nvarchar(100) NOT NULL,
    [Description] nvarchar(500) NOT NULL,
    [IsIndoor] bit NOT NULL,
    [IsActive] bit NOT NULL DEFAULT CAST(1 AS bit),
    [HourlyRate] decimal(18,2) NOT NULL,
    [MaxPlayers] int NOT NULL,
    [CreatedAt] datetime2 NOT NULL DEFAULT (GETUTCDATE()),
    [UpdatedAt] datetime2 NULL,
    CONSTRAINT [PK_Courts] PRIMARY KEY ([Id])
);
GO

CREATE TABLE [ProductCategories] (
    [Id] int NOT NULL IDENTITY,
    [Name] nvarchar(100) NOT NULL,
    [Description] nvarchar(500) NULL,
    [IsActive] bit NOT NULL DEFAULT CAST(1 AS bit),
    [CreatedAt] datetime2 NOT NULL DEFAULT (GETUTCDATE()),
    [UpdatedAt] datetime2 NULL,
    CONSTRAINT [PK_ProductCategories] PRIMARY KEY ([Id])
);
GO

CREATE TABLE [ProductTypes] (
    [Id] int NOT NULL IDENTITY,
    [Name] nvarchar(100) NOT NULL,
    [Description] nvarchar(500) NULL,
    [IsActive] bit NOT NULL DEFAULT CAST(1 AS bit),
    [CreatedAt] datetime2 NOT NULL DEFAULT (GETUTCDATE()),
    [UpdatedAt] datetime2 NULL,
    CONSTRAINT [PK_ProductTypes] PRIMARY KEY ([Id])
);
GO

CREATE TABLE [Roles] (
    [Id] int NOT NULL IDENTITY,
    [Name] nvarchar(50) NOT NULL,
    [Description] nvarchar(200) NULL,
    [CreatedAt] datetime2 NOT NULL DEFAULT (GETUTCDATE()),
    [IsActive] bit NOT NULL DEFAULT CAST(1 AS bit),
    CONSTRAINT [PK_Roles] PRIMARY KEY ([Id])
);
GO

CREATE TABLE [Tournaments] (
    [Id] int NOT NULL IDENTITY,
    [Name] nvarchar(200) NOT NULL,
    [Description] nvarchar(2000) NOT NULL,
    [StartDate] datetime2 NOT NULL,
    [EndDate] datetime2 NOT NULL,
    [RegistrationDeadline] datetime2 NOT NULL,
    [MaxParticipants] int NOT NULL,
    [EntryFee] decimal(18,2) NOT NULL,
    [Status] nvarchar(50) NOT NULL DEFAULT N'Upcoming',
    [PrizeInfo] nvarchar(1000) NULL,
    [CreatedAt] datetime2 NOT NULL DEFAULT (GETUTCDATE()),
    [UpdatedAt] datetime2 NULL,
    CONSTRAINT [PK_Tournaments] PRIMARY KEY ([Id])
);
GO

CREATE TABLE [Users] (
    [Id] int NOT NULL IDENTITY,
    [Username] nvarchar(100) NOT NULL,
    [Email] nvarchar(255) NOT NULL,
    [FirstName] nvarchar(100) NOT NULL,
    [LastName] nvarchar(100) NOT NULL,
    [PasswordHash] nvarchar(max) NOT NULL,
    [PasswordSalt] nvarchar(max) NOT NULL,
    [PhoneNumber] nvarchar(30) NULL,
    [IsActive] bit NOT NULL DEFAULT CAST(1 AS bit),
    [CreatedAt] datetime2 NOT NULL DEFAULT (GETUTCDATE()),
    [UpdatedAt] datetime2 NULL,
    CONSTRAINT [PK_Users] PRIMARY KEY ([Id])
);
GO

CREATE TABLE [Products] (
    [Id] int NOT NULL IDENTITY,
    [Name] nvarchar(200) NOT NULL,
    [Description] nvarchar(1000) NOT NULL,
    [Price] decimal(18,2) NOT NULL,
    [StockQuantity] int NOT NULL,
    [ProductCategoryId] int NOT NULL,
    [ProductTypeId] int NOT NULL,
    [ImageUrl] nvarchar(500) NULL,
    [IsActive] bit NOT NULL DEFAULT CAST(1 AS bit),
    [CreatedAt] datetime2 NOT NULL DEFAULT (GETUTCDATE()),
    [UpdatedAt] datetime2 NULL,
    [ProductState] nvarchar(1000) NOT NULL,
    CONSTRAINT [PK_Products] PRIMARY KEY ([Id]),
    CONSTRAINT [FK_Products_ProductCategories_ProductCategoryId] FOREIGN KEY ([ProductCategoryId]) REFERENCES [ProductCategories] ([Id]) ON DELETE NO ACTION,
    CONSTRAINT [FK_Products_ProductTypes_ProductTypeId] FOREIGN KEY ([ProductTypeId]) REFERENCES [ProductTypes] ([Id]) ON DELETE NO ACTION
);
GO

CREATE TABLE [Matches] (
    [Id] int NOT NULL IDENTITY,
    [TournamentId] int NOT NULL,
    [CourtId] int NOT NULL,
    [ScheduledTime] datetime2 NOT NULL,
    [ActualStartTime] datetime2 NULL,
    [ActualEndTime] datetime2 NULL,
    [Status] nvarchar(50) NOT NULL DEFAULT N'Scheduled',
    [WinnerTeamId] int NULL,
    [Score] nvarchar(100) NULL,
    [Notes] nvarchar(1000) NULL,
    [CreatedAt] datetime2 NOT NULL DEFAULT (GETUTCDATE()),
    [UpdatedAt] datetime2 NULL,
    CONSTRAINT [PK_Matches] PRIMARY KEY ([Id]),
    CONSTRAINT [FK_Matches_Courts_CourtId] FOREIGN KEY ([CourtId]) REFERENCES [Courts] ([Id]) ON DELETE NO ACTION,
    CONSTRAINT [FK_Matches_Tournaments_TournamentId] FOREIGN KEY ([TournamentId]) REFERENCES [Tournaments] ([Id]) ON DELETE NO ACTION
);
GO

CREATE TABLE [Memberships] (
    [Id] int NOT NULL IDENTITY,
    [UserId] int NOT NULL,
    [MembershipType] nvarchar(50) NOT NULL,
    [StartDate] datetime2 NOT NULL,
    [EndDate] datetime2 NOT NULL,
    [Price] decimal(18,2) NOT NULL,
    [IsActive] bit NOT NULL DEFAULT CAST(1 AS bit),
    [CreatedAt] datetime2 NOT NULL DEFAULT (GETUTCDATE()),
    [UpdatedAt] datetime2 NULL,
    CONSTRAINT [PK_Memberships] PRIMARY KEY ([Id]),
    CONSTRAINT [FK_Memberships_Users_UserId] FOREIGN KEY ([UserId]) REFERENCES [Users] ([Id]) ON DELETE NO ACTION
);
GO

CREATE TABLE [Orders] (
    [Id] int NOT NULL IDENTITY,
    [UserId] int NOT NULL,
    [OrderNumber] nvarchar(100) NOT NULL,
    [TotalAmount] decimal(18,2) NOT NULL,
    [Status] nvarchar(50) NOT NULL DEFAULT N'Pending',
    [ShippingAddress] nvarchar(500) NOT NULL,
    [Notes] nvarchar(1000) NULL,
    [CreatedAt] datetime2 NOT NULL DEFAULT (GETUTCDATE()),
    [UpdatedAt] datetime2 NULL,
    CONSTRAINT [PK_Orders] PRIMARY KEY ([Id]),
    CONSTRAINT [FK_Orders_Users_UserId] FOREIGN KEY ([UserId]) REFERENCES [Users] ([Id]) ON DELETE NO ACTION
);
GO

CREATE TABLE [Reservations] (
    [Id] int NOT NULL IDENTITY,
    [CourtId] int NOT NULL,
    [UserId] int NOT NULL,
    [StartTime] datetime2 NOT NULL,
    [EndTime] datetime2 NOT NULL,
    [TotalPrice] decimal(18,2) NOT NULL,
    [Status] nvarchar(50) NOT NULL DEFAULT N'Pending',
    [Notes] nvarchar(1000) NULL,
    [CreatedAt] datetime2 NOT NULL DEFAULT (GETUTCDATE()),
    [UpdatedAt] datetime2 NULL,
    CONSTRAINT [PK_Reservations] PRIMARY KEY ([Id]),
    CONSTRAINT [FK_Reservations_Courts_CourtId] FOREIGN KEY ([CourtId]) REFERENCES [Courts] ([Id]) ON DELETE NO ACTION,
    CONSTRAINT [FK_Reservations_Users_UserId] FOREIGN KEY ([UserId]) REFERENCES [Users] ([Id]) ON DELETE NO ACTION
);
GO

CREATE TABLE [TournamentParticipants] (
    [Id] int NOT NULL IDENTITY,
    [TournamentId] int NOT NULL,
    [UserId] int NOT NULL,
    [Status] nvarchar(50) NOT NULL DEFAULT N'Registered',
    [RegisteredAt] datetime2 NOT NULL DEFAULT (GETUTCDATE()),
    [ConfirmedAt] datetime2 NULL,
    CONSTRAINT [PK_TournamentParticipants] PRIMARY KEY ([Id]),
    CONSTRAINT [FK_TournamentParticipants_Tournaments_TournamentId] FOREIGN KEY ([TournamentId]) REFERENCES [Tournaments] ([Id]) ON DELETE NO ACTION,
    CONSTRAINT [FK_TournamentParticipants_Users_UserId] FOREIGN KEY ([UserId]) REFERENCES [Users] ([Id]) ON DELETE NO ACTION
);
GO

CREATE TABLE [UserRoles] (
    [Id] int NOT NULL IDENTITY,
    [UserId] int NOT NULL,
    [RoleId] int NOT NULL,
    [DateAssigned] datetime2 NOT NULL DEFAULT (GETUTCDATE()),
    CONSTRAINT [PK_UserRoles] PRIMARY KEY ([Id]),
    CONSTRAINT [FK_UserRoles_Roles_RoleId] FOREIGN KEY ([RoleId]) REFERENCES [Roles] ([Id]) ON DELETE NO ACTION,
    CONSTRAINT [FK_UserRoles_Users_UserId] FOREIGN KEY ([UserId]) REFERENCES [Users] ([Id]) ON DELETE CASCADE
);
GO

CREATE TABLE [Assets] (
    [Id] int NOT NULL IDENTITY,
    [ProductId] int NOT NULL,
    [Base64Image] nvarchar(max) NOT NULL,
    [DisplayOrder] int NOT NULL DEFAULT 0,
    [IsPrimary] bit NOT NULL DEFAULT CAST(0 AS bit),
    [CreatedAt] datetime2 NOT NULL DEFAULT (GETUTCDATE()),
    [UpdatedAt] datetime2 NULL,
    CONSTRAINT [PK_Assets] PRIMARY KEY ([Id]),
    CONSTRAINT [FK_Assets_Products_ProductId] FOREIGN KEY ([ProductId]) REFERENCES [Products] ([Id]) ON DELETE CASCADE
);
GO

CREATE TABLE [MatchParticipants] (
    [Id] int NOT NULL IDENTITY,
    [MatchId] int NOT NULL,
    [UserId] int NOT NULL,
    [TeamNumber] int NOT NULL,
    [Role] nvarchar(50) NOT NULL DEFAULT N'Player',
    [CreatedAt] datetime2 NOT NULL DEFAULT (GETUTCDATE()),
    CONSTRAINT [PK_MatchParticipants] PRIMARY KEY ([Id]),
    CONSTRAINT [FK_MatchParticipants_Matches_MatchId] FOREIGN KEY ([MatchId]) REFERENCES [Matches] ([Id]) ON DELETE CASCADE,
    CONSTRAINT [FK_MatchParticipants_Users_UserId] FOREIGN KEY ([UserId]) REFERENCES [Users] ([Id]) ON DELETE NO ACTION
);
GO

CREATE TABLE [OrderItems] (
    [Id] int NOT NULL IDENTITY,
    [OrderId] int NOT NULL,
    [ProductId] int NOT NULL,
    [Quantity] int NOT NULL,
    [UnitPrice] decimal(18,2) NOT NULL,
    [TotalPrice] decimal(18,2) NOT NULL,
    [CreatedAt] datetime2 NOT NULL DEFAULT (GETUTCDATE()),
    CONSTRAINT [PK_OrderItems] PRIMARY KEY ([Id]),
    CONSTRAINT [FK_OrderItems_Orders_OrderId] FOREIGN KEY ([OrderId]) REFERENCES [Orders] ([Id]) ON DELETE CASCADE,
    CONSTRAINT [FK_OrderItems_Products_ProductId] FOREIGN KEY ([ProductId]) REFERENCES [Products] ([Id]) ON DELETE NO ACTION
);
GO

CREATE TABLE [Payments] (
    [Id] int NOT NULL IDENTITY,
    [UserId] int NOT NULL,
    [PaymentType] nvarchar(50) NOT NULL,
    [ReservationId] int NULL,
    [MembershipId] int NULL,
    [OrderId] int NULL,
    [Amount] decimal(18,2) NOT NULL,
    [PaymentMethod] nvarchar(50) NOT NULL,
    [Status] nvarchar(50) NOT NULL DEFAULT N'Pending',
    [TransactionId] nvarchar(200) NULL,
    [PaymentDate] datetime2 NOT NULL DEFAULT (GETUTCDATE()),
    [CreatedAt] datetime2 NOT NULL DEFAULT (GETUTCDATE()),
    CONSTRAINT [PK_Payments] PRIMARY KEY ([Id]),
    CONSTRAINT [FK_Payments_Memberships_MembershipId] FOREIGN KEY ([MembershipId]) REFERENCES [Memberships] ([Id]) ON DELETE SET NULL,
    CONSTRAINT [FK_Payments_Orders_OrderId] FOREIGN KEY ([OrderId]) REFERENCES [Orders] ([Id]) ON DELETE SET NULL,
    CONSTRAINT [FK_Payments_Reservations_ReservationId] FOREIGN KEY ([ReservationId]) REFERENCES [Reservations] ([Id]) ON DELETE SET NULL,
    CONSTRAINT [FK_Payments_Users_UserId] FOREIGN KEY ([UserId]) REFERENCES [Users] ([Id]) ON DELETE NO ACTION
);
GO

CREATE INDEX [IX_Assets_ProductId] ON [Assets] ([ProductId]);
GO

CREATE INDEX [IX_Assets_ProductId_DisplayOrder] ON [Assets] ([ProductId], [DisplayOrder]);
GO

CREATE INDEX [IX_Courts_Name] ON [Courts] ([Name]);
GO

CREATE INDEX [IX_Matches_CourtId] ON [Matches] ([CourtId]);
GO

CREATE INDEX [IX_Matches_ScheduledTime] ON [Matches] ([ScheduledTime]);
GO

CREATE INDEX [IX_Matches_TournamentId] ON [Matches] ([TournamentId]);
GO

CREATE UNIQUE INDEX [IX_MatchParticipants_MatchId_UserId] ON [MatchParticipants] ([MatchId], [UserId]);
GO

CREATE INDEX [IX_MatchParticipants_UserId] ON [MatchParticipants] ([UserId]);
GO

CREATE INDEX [IX_Memberships_UserId] ON [Memberships] ([UserId]);
GO

CREATE INDEX [IX_Memberships_UserId_IsActive] ON [Memberships] ([UserId], [IsActive]);
GO

CREATE INDEX [IX_OrderItems_OrderId] ON [OrderItems] ([OrderId]);
GO

CREATE INDEX [IX_OrderItems_ProductId] ON [OrderItems] ([ProductId]);
GO

CREATE UNIQUE INDEX [IX_Orders_OrderNumber] ON [Orders] ([OrderNumber]);
GO

CREATE INDEX [IX_Orders_Status] ON [Orders] ([Status]);
GO

CREATE INDEX [IX_Orders_UserId] ON [Orders] ([UserId]);
GO

CREATE UNIQUE INDEX [IX_Payments_MembershipId] ON [Payments] ([MembershipId]) WHERE [MembershipId] IS NOT NULL;
GO

CREATE UNIQUE INDEX [IX_Payments_OrderId] ON [Payments] ([OrderId]) WHERE [OrderId] IS NOT NULL;
GO

CREATE UNIQUE INDEX [IX_Payments_ReservationId] ON [Payments] ([ReservationId]) WHERE [ReservationId] IS NOT NULL;
GO

CREATE INDEX [IX_Payments_Status] ON [Payments] ([Status]);
GO

CREATE INDEX [IX_Payments_TransactionId] ON [Payments] ([TransactionId]);
GO

CREATE INDEX [IX_Payments_UserId] ON [Payments] ([UserId]);
GO

CREATE INDEX [IX_ProductCategories_Name] ON [ProductCategories] ([Name]);
GO

CREATE INDEX [IX_Products_Name] ON [Products] ([Name]);
GO

CREATE INDEX [IX_Products_ProductCategoryId] ON [Products] ([ProductCategoryId]);
GO

CREATE INDEX [IX_Products_ProductTypeId] ON [Products] ([ProductTypeId]);
GO

CREATE INDEX [IX_ProductTypes_Name] ON [ProductTypes] ([Name]);
GO

CREATE INDEX [IX_Reservations_CourtId_StartTime_EndTime] ON [Reservations] ([CourtId], [StartTime], [EndTime]);
GO

CREATE INDEX [IX_Reservations_Status] ON [Reservations] ([Status]);
GO

CREATE INDEX [IX_Reservations_UserId] ON [Reservations] ([UserId]);
GO

CREATE UNIQUE INDEX [IX_Roles_Name] ON [Roles] ([Name]);
GO

CREATE UNIQUE INDEX [IX_TournamentParticipants_TournamentId_UserId] ON [TournamentParticipants] ([TournamentId], [UserId]);
GO

CREATE INDEX [IX_TournamentParticipants_UserId] ON [TournamentParticipants] ([UserId]);
GO

CREATE INDEX [IX_Tournaments_StartDate] ON [Tournaments] ([StartDate]);
GO

CREATE INDEX [IX_Tournaments_Status] ON [Tournaments] ([Status]);
GO

CREATE INDEX [IX_UserRoles_RoleId] ON [UserRoles] ([RoleId]);
GO

CREATE UNIQUE INDEX [IX_UserRoles_UserId_RoleId] ON [UserRoles] ([UserId], [RoleId]);
GO

CREATE UNIQUE INDEX [IX_Users_Email] ON [Users] ([Email]);
GO

CREATE UNIQUE INDEX [IX_Users_Username] ON [Users] ([Username]);
GO

INSERT INTO [__EFMigrationsHistory] ([MigrationId], [ProductVersion])
VALUES (N'20260514105859_InitialCreate', N'8.0.10');
GO

COMMIT;
GO

