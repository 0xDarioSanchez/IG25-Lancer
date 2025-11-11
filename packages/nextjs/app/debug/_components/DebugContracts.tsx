"use client";

import { useEffect, useState } from "react";
import { ICounter } from "./ICounter";
import { ethers } from "ethers";

const contractAddress = "0x664508a7178451da209b9387f671c347eb28c0cc";
const provider = new ethers.JsonRpcProvider(process.env.NEXT_PUBLIC_RPC_URL || "");
const privateKey = process.env.NEXT_PUBLIC_PRIVATE_KEY || "";
const signer = new ethers.Wallet(privateKey, provider);
const contract = new ethers.Contract(contractAddress, ICounter, signer);

export function DebugContracts() {
  const [number, setNumber] = useState<number | null>(null);
  const [inputNumber, setInputNumber] = useState<string>("");
  const [txStatus, setTxStatus] = useState<{
    status: "none" | "pending" | "success" | "error";
    message: string;
    operation?: string;
  }>({ status: "none", message: "" });

  const fetchNumber = async () => {
    try {
      const currentNumber = await contract.number();
      console.log(currentNumber);
      setNumber(Number(currentNumber));
    } catch (error) {
      console.error("Error fetching number:", error);
    }
  };

  useEffect(() => {
    fetchNumber();
  }, []);

  const handleTransaction = async (
    operation: () => Promise<any>,
    pendingMessage: string,
    successMessage: string,
    operationType: string,
  ) => {
    // Don't proceed if another operation is pending
    if (txStatus.status === "pending") return;

    try {
      setTxStatus({ status: "pending", message: pendingMessage, operation: operationType });
      await operation();
      setTxStatus({ status: "success", message: successMessage });
    } catch (error: any) {
      console.error(`Error in ${operationType}:`, error);
      setTxStatus({
        status: "error",
        message: error.reason || error.message || "Transaction failed",
      });
    }
    // Clear status after 5 seconds
    setTimeout(() => {
      setTxStatus({ status: "none", message: "" });
    }, 5000);
  };

  const setANumber = () => {
    if (!inputNumber || isNaN(Number(inputNumber))) {
      setTxStatus({
        status: "error",
        message: "Please enter a valid number",
      });
      return;
    }

    handleTransaction(
      async () => {
        const tx = await contract.setNumber(Number(inputNumber));
        await tx.wait();
        await fetchNumber();
      },
      "Setting number...",
      `Number set to ${inputNumber} successfully!`,
      "setNumber",
    );
  };

  const addNumber = () => {
    if (!inputNumber || isNaN(Number(inputNumber))) {
      setTxStatus({
        status: "error",
        message: "Please enter a valid number",
      });
      return;
    }

    handleTransaction(
      async () => {
        const tx = await contract.addNumber(Number(inputNumber));
        await tx.wait();
        await fetchNumber();
      },
      "Adding number...",
      `Added ${inputNumber} successfully!`,
      "addNumber",
    );
  };

  const mulNumber = () => {
    if (!inputNumber || isNaN(Number(inputNumber))) {
      setTxStatus({
        status: "error",
        message: "Please enter a valid number",
      });
      return;
    }

    handleTransaction(
      async () => {
        const tx = await contract.mulNumber(Number(inputNumber));
        await tx.wait();
        await fetchNumber();
      },
      "Multiplying number...",
      `Multiplied by ${inputNumber} successfully!`,
      "mulNumber",
    );
  };

  const increment = () => {
    handleTransaction(
      async () => {
        const tx = await contract.increment();
        await tx.wait();
        await fetchNumber();
      },
      "Incrementing number...",
      "Number incremented successfully!",
      "increment",
    );
  };

  // Helper function to determine if a button should be disabled
  const isOperationDisabled = (operation: string) => {
    return txStatus.status === "pending" && (!txStatus.operation || txStatus.operation === operation);
  };

  return (
    <div className="flex flex-col items-center justify-center w-full my-auto">
      <div className="bg-white dark:bg-gray-900/95 shadow-2xl rounded-3xl w-full max-w-5xl p-8 border border-slate-200 dark:border-blue-500/30">
        <div className="flex items-center justify-center mb-8">
          <div className="px-6 py-3 rounded-full">
            <h1 className="text-4xl font-extrabold tracking-tight text-blue-600 dark:text-cyan-400">
              Counter Contract
            </h1>
          </div>
        </div>

        <div className="flex justify-center mb-10">
          <div className="bg-slate-100/80 dark:bg-blue-900/40 rounded-2xl px-8 py-6 shadow-xl border border-slate-200 dark:border-blue-500/20 backdrop-blur-md text-center">
            <div className="text-lg font-medium text-slate-600 dark:text-blue-200 mb-1">Current Number</div>
            <div className="text-5xl font-bold text-pink-500 dark:text-pink-400">
              {number !== null ? (
                number
              ) : (
                <div className="flex items-center justify-center">
                  <div className="h-8 w-8 border-t-2 border-b-2 border-pink-500 dark:border-pink-400 rounded-full animate-spin"></div>
                </div>
              )}
            </div>
          </div>
        </div>

        {/* Transaction Status Alert */}
        {txStatus.status !== "none" && (
          <div
            className={`transition-all duration-300 alert ${
              txStatus.status === "pending"
                ? "bg-blue-50 text-blue-700 dark:bg-blue-900/50 dark:text-blue-200"
                : txStatus.status === "success"
                  ? "bg-green-50 text-green-700 dark:bg-green-900/50 dark:text-green-200"
                  : "bg-red-50 text-red-700 dark:bg-red-900/50 dark:text-red-200"
            } mb-8 border ${
              txStatus.status === "pending"
                ? "border-blue-200 dark:border-blue-500/40"
                : txStatus.status === "success"
                  ? "border-green-200 dark:border-green-500/40"
                  : "border-red-200 dark:border-red-500/40"
            } shadow-lg backdrop-blur-md rounded-2xl`}
          >
            <div className="flex items-center">
              {txStatus.status === "pending" && (
                <div className="loading loading-spinner loading-md mr-3 text-blue-500 dark:text-blue-400" />
              )}
              {txStatus.status === "success" && (
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  className="h-6 w-6 mr-3 text-green-500 dark:text-green-400"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                >
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 13l4 4L19 7" />
                </svg>
              )}
              {txStatus.status === "error" && (
                <svg
                  xmlns="http://www.w3.org/2000/svg"
                  className="h-6 w-6 mr-3 text-red-500 dark:text-red-400"
                  fill="none"
                  viewBox="0 0 24 24"
                  stroke="currentColor"
                >
                  <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
                </svg>
              )}
              <span className="font-medium">{txStatus.message}</span>
            </div>
          </div>
        )}

        <div className="space-y-8">
          <div className="bg-slate-50 dark:bg-gray-800/80 rounded-2xl p-6 border border-slate-200 dark:border-blue-500/20">
            <h2 className="text-xl font-semibold text-slate-700 dark:text-blue-200 mb-4">Number Operations</h2>
            <div className="flex flex-col sm:flex-row gap-6 justify-between items-center">
              <div className="w-full sm:w-1/3">
                <input
                  type="number"
                  value={inputNumber}
                  onChange={e => setInputNumber(e.target.value)}
                  className="input bg-white/70 dark:bg-blue-900/30 border border-slate-300 dark:border-blue-500/30 focus:border-blue-400 dark:focus:border-blue-400 focus:bg-white dark:focus:bg-blue-900/40 text-slate-800 dark:text-white placeholder-slate-400 dark:placeholder-blue-300/50 w-full rounded-xl"
                  placeholder="Enter a number"
                  disabled={txStatus.status === "pending"}
                />
              </div>
              <div className="flex flex-wrap gap-3 justify-center">
                <button
                  className={`btn border-0 shadow-lg px-4 rounded-xl font-semibold 
                    ${
                      isOperationDisabled("setNumber")
                        ? "bg-slate-200 text-slate-400 dark:bg-blue-900/50 dark:text-blue-300/70 cursor-not-allowed"
                        : "bg-blue-500 hover:bg-blue-600 dark:bg-blue-600 dark:hover:bg-blue-500 text-white transform hover:scale-105 transition-all duration-300"
                    }`}
                  onClick={setANumber}
                  disabled={isOperationDisabled("setNumber")}
                >
                  {txStatus.status === "pending" && txStatus.operation === "setNumber" ? (
                    <div className="flex items-center">
                      <div className="h-5 w-5 border-t-2 border-b-2 border-white rounded-full animate-spin mr-2"></div>
                      Setting...
                    </div>
                  ) : (
                    <div className="flex items-center">
                      <svg
                        xmlns="http://www.w3.org/2000/svg"
                        className="h-5 w-5 mr-2"
                        fill="none"
                        viewBox="0 0 24 24"
                        stroke="currentColor"
                      >
                        <path
                          strokeLinecap="round"
                          strokeLinejoin="round"
                          strokeWidth={2}
                          d="M15.232 5.232l3.536 3.536m-2.036-5.036a2.5 2.5 0 113.536 3.536L6.5 21.036H3v-3.572L16.732 3.732z"
                        />
                      </svg>
                      Set Number
                    </div>
                  )}
                </button>

                <button
                  className={`btn border-0 shadow-lg px-4 rounded-xl font-semibold 
                    ${
                      isOperationDisabled("addNumber")
                        ? "bg-slate-200 text-slate-400 dark:bg-purple-900/50 dark:text-purple-300/70 cursor-not-allowed"
                        : "bg-purple-500 hover:bg-purple-600 dark:bg-purple-600 dark:hover:bg-purple-500 text-white transform hover:scale-105 transition-all duration-300"
                    }`}
                  onClick={addNumber}
                  disabled={isOperationDisabled("addNumber")}
                >
                  {txStatus.status === "pending" && txStatus.operation === "addNumber" ? (
                    <div className="flex items-center">
                      <div className="h-5 w-5 border-t-2 border-b-2 border-white rounded-full animate-spin mr-2"></div>
                      Adding...
                    </div>
                  ) : (
                    <div className="flex items-center">
                      <svg
                        xmlns="http://www.w3.org/2000/svg"
                        className="h-5 w-5 mr-2"
                        fill="none"
                        viewBox="0 0 24 24"
                        stroke="currentColor"
                      >
                        <path
                          strokeLinecap="round"
                          strokeLinejoin="round"
                          strokeWidth={2}
                          d="M12 6v6m0 0v6m0-6h6m-6 0H6"
                        />
                      </svg>
                      Add Number
                    </div>
                  )}
                </button>

                <button
                  className={`btn border-0 shadow-lg px-4 rounded-xl font-semibold 
                    ${
                      isOperationDisabled("mulNumber")
                        ? "bg-slate-200 text-slate-400 dark:bg-orange-900/50 dark:text-orange-300/70 cursor-not-allowed"
                        : "bg-orange-500 hover:bg-orange-600 dark:bg-orange-500 dark:hover:bg-orange-400 text-white transform hover:scale-105 transition-all duration-300"
                    }`}
                  onClick={mulNumber}
                  disabled={isOperationDisabled("mulNumber")}
                >
                  {txStatus.status === "pending" && txStatus.operation === "mulNumber" ? (
                    <div className="flex items-center">
                      <div className="h-5 w-5 border-t-2 border-b-2 border-white rounded-full animate-spin mr-2"></div>
                      Multiplying...
                    </div>
                  ) : (
                    <div className="flex items-center">
                      <svg
                        xmlns="http://www.w3.org/2000/svg"
                        className="h-5 w-5 mr-2"
                        fill="none"
                        viewBox="0 0 24 24"
                        stroke="currentColor"
                      >
                        <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 4v16m8-8H4" />
                      </svg>
                      Multiply
                    </div>
                  )}
                </button>
              </div>
            </div>
          </div>

          <div className="flex justify-center">
            <button
              className={`relative overflow-hidden btn border-0 shadow-xl px-8 py-3 rounded-xl font-semibold text-lg 
                ${
                  isOperationDisabled("increment")
                    ? "bg-slate-200 text-slate-400 dark:bg-blue-900/50 dark:text-blue-300/70 cursor-not-allowed"
                    : "bg-cyan-500 hover:bg-cyan-600 dark:bg-cyan-600 dark:hover:bg-cyan-500 text-white transform hover:scale-105 transition-all duration-300"
                }`}
              onClick={increment}
              disabled={isOperationDisabled("increment")}
            >
              {txStatus.status === "pending" && txStatus.operation === "increment" ? (
                <div className="flex items-center">
                  <div className="h-5 w-5 border-t-2 border-b-2 border-white rounded-full animate-spin mr-2"></div>
                  Incrementing...
                </div>
              ) : (
                <div className="flex items-center">
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    className="h-5 w-5 mr-2"
                    fill="none"
                    viewBox="0 0 24 24"
                    stroke="currentColor"
                  >
                    <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M5 10l7-7m0 0l7 7m-7-7v18" />
                  </svg>
                  Increment
                </div>
              )}
            </button>
          </div>
        </div>
      </div>
    </div>
  );
}
