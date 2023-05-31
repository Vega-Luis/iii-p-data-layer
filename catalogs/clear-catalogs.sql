USE [III P]
GO

DELETE FROM [dbo].[AccountTypeXBusinessRuleDays]
DELETE FROM [dbo].[AccountTypeXBusinessRuleMonths]
DELETE FROM [dbo].[AccountTypeXBusinessRuleMonetaryAmount]
DELETE FROM [dbo].[AccountTypeXBusinessRuleOperation]
DELETE FROM [dbo].[AccountTypeXBusinessRuleRate]
DELETE FROM [dbo].[AccountTypeXBussinesRule]
DBCC CHECKIDENT ('AccountTypeXBussinesRule', RESEED, 0)
DELETE FROM [dbo].[AccountType]
DBCC CHECKIDENT ('AccountType', RESEED, 0)
DELETE FROM [dbo].[BusinessRule]
DBCC CHECKIDENT ('BusinessRule', RESEED, 0)
DELETE FROM [dbo].BusinessRuleType
DBCC CHECKIDENT ('BusinessRuleType', RESEED, 0)
DELETE FROM [dbo].DocumentType
DBCC CHECKIDENT ('DocumentType', RESEED, 0)
DELETE FROM dbo.InvalidationMotive
DBCC CHECKIDENT ('InvalidationMotive', RESEED, 0)
DELETE FROM dbo.MovementType
DBCC CHECKIDENT ('MovementType', RESEED, 0)
DELETE FROM dbo.[User]
DBCC CHECKIDENT ('User', RESEED, 0)


GO


