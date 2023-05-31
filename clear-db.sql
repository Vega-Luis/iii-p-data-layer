SELECT * FROM  dbo.Movement
SELECT * FROM  dbo.SuspiciousMovement
SELECT * FROM  dbo.InterestMoratorMovement
SELECT * FROM  dbo.CurrentInterestMovement
SELECT * FROM  dbo.SubAccountState
SELECT * FROM  dbo.AccountState

SELECT * FROM   [dbo].[AccountTypeXBusinessRuleMonths]
SELECT * FROM  [dbo].[AccountTypeXBusinessRuleMonetaryAmount]
SELECT * FROM   [dbo].[AccountTypeXBusinessRuleOperation]
SELECT * FROM   [dbo].[AccountTypeXBusinessRuleRate]
SELECT * FROM   [dbo].[AccountTypeXBussinesRule]
--DBCC CHECKIDENT ('AccountTypeXBussinesRule', RESEED, 0)
SELECT * FROM   [dbo].[AccountType]
--DBCC CHECKIDENT ('AccountType', RESEED, 0)
SELECT * FROM   [dbo].[BusinessRule]
--DBCC CHECKIDENT ('BusinessRule', RESEED, 0)
SELECT * FROM   [dbo].BusinessRuleType
--DBCC CHECKIDENT ('BusinessRuleType', RESEED, 0)
SELECT * FROM   [dbo].DocumentType
--DBCC CHECKIDENT ('DocumentType', RESEED, 0)
SELECT * FROM   dbo.InvalidationMotive
--DBCC CHECKIDENT ('InvalidationMotive', RESEED, 0)
SELECT * FROM   dbo.MovementType
--DBCC CHECKIDENT ('MovementType', RESEED, 0)
SELECT * FROM   dbo.[User]
--DBCC CHECKIDENT ('User', RESEED, 0)
SELECT * FROM dbo.UserType

DELETE dbo.Movement
DBCC CHECKIDENT ('Movement', RESEED, 0)
DELETE dbo.SuspiciousMovement
DBCC CHECKIDENT ('SuspiciousMovement', RESEED, 0)
DELETE dbo.InterestMoratorMovement
DBCC CHECKIDENT ('InterestMoratorMovement', RESEED, 0)
DELETE dbo.CurrentInterestMovement
DBCC CHECKIDENT ('CurrentInterestMovement', RESEED, 0)
DELETE dbo.PhysicalCard
DBCC CHECKIDENT ('PhysicalCard', RESEED, 0)
DELETE dbo.SubAccountState
DBCC CHECKIDENT ('SubAccountState', RESEED, 0)
DELETE dbo.AccountState
DBCC CHECKIDENT ('AccountState', RESEED, 0)
DELETE dbo.AdditionalAccount
DELETE dbo.MasterAccount
DELETE dbo.CreditCardAccount
DBCC CHECKIDENT ('CreditCardAccount', RESEED, 0)
DELETE dbo.CardHolder

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
