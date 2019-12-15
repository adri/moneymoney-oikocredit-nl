-- Inofficial Oikocredit Extension for MoneyMoney
-- Fetches balances and transactions.
--
-- MIT License

-- Copyright (c) 2019 Adrian Philipp

-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:

-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.

-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.


WebBanking{
  version = 0.1,
  description = "Include your Oikocredit funds as oportfolio in MoneyMoney by providing a Oikocredit username and password",
  services= { "Oikocredit Nederland" }
}

local connection = Connection()
local currency = "EUR"
local serviceName = "Oikocredit Nederland"

function SupportsBank (protocol, bankCode)
  return protocol == ProtocolWebBanking and bankCode == serviceName
end

function InitializeSession (protocol, bankCode, username, username2, password, username3)
  MM.printStatus("Login")
  connection.language = "nl-nl"
  html = HTML(connection:get("https://www.oikocredit.nl/login"))

  html:xpath("//input[@name='formdata[username]']"):attr("value", username)
  html:xpath("//input[@name='formdata[password][real]']"):attr("value", password)

  html = HTML(connection:request(html:xpath("//button[@id='login-submit']"):click()))

  if html:xpath("//a[starts-with(@href, '/logout')]"):length() == 0 then
          MM.printStatus("Login Failed")
    return LoginFailed
  end
end

function ListAccounts (knownAccounts)
  local name = "Oikocredit Nederland"

  local accounts = {}

  for _, account in ipairs(jsonRPC("getAccountBalance", {})) do
      table.insert(
        accounts,
        {
          name = name,
          bankCode = serviceName,
          currency = currency,
          owner = account.owner,
          accountNumber = account.accountNumber,
          subAccount = account.accountId,
          type = "AccountTypeSavings",
        }
      )
  end

  return accounts
end

function RefreshAccount (account, since)
  local accountBalance = jsonRPC("getSingleAccountBalance", {account.subAccount})
  local balance = parseAmount(accountBalance.value)

  local transactions = {}
  for _, transaction in ipairs(jsonRPC("getTransactionHistory", {account.subAccount})) do
    table.insert(
      transactions,
      {
        bookingDate = dutchDateToTimestamp(transaction.date),
        purpose = transaction.description,
        amount = parseAmount(transaction.amount)
      }
    )
  end

  return {balance=balance, transactions=transactions}
end

function EndSession()
  html = HTML(connection:request(html:xpath("//a[starts-with(@href, '/logout')]"):click()))
end

-- Helper Functions
function jsonRPC(method, params)
  local body = JSON():set({
    jsonrpc = "2.0",
    method = method,
    params = params,
    id = 1
  }):json()

  local response = JSON(
    connection:post("https://www.oikocredit.nl/l/my_oikocredit/endpoint", body, "application/json")
  ):dictionary()

  return response.result
end

function stripChars(str, chrs)
  s = str:gsub("["..chrs:gsub("%W","%%%1").."]", '')
  return s
end

function parseAmount(amount)
  return tonumber(stripChars(amount, " .,€")) / 100
end

function dutchDateToTimestamp(date)
  local day, monthName, year=date:match("(%d+) (%a+) (%d+)")

  month={
    januari=1,
    februari=2,
    maart=3,
    april=4,
    mei=5,
    juni=6,
    juli=7,
    augustus=8,
    september =9,
    oktober=10,
    november=11,
    december =12
  }

  return os.time({
      year = tonumber(year),
      month = month[monthName],
      day = tonumber(day)
  })
end

-- SIGNATURE: MCwCFFSU/4wDHG1V4Tr/K9DEXKQpLK1lAhQG6FSN+KszEmyGCizIN9b0O1nxGw==
