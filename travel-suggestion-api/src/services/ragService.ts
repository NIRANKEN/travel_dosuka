import * as z from "zod";
import { tool } from "@langchain/core/tools";
import { createAgent } from "langchain";
import { model, embeddings } from "../config/models.js";
import { OutputTestOptions, RagResponse } from "../types/index.js";
import { MultiQueryRetriever } from "@langchain/classic/retrievers/multi_query";
import { DocumentInterface } from "@langchain/core/documents";
import { RETRIEVAL_CONFIG } from "../config/constants.js";
import { FirestoreVectorStore } from "./firestoreVectorStore.js";

const retrieveSchema = z.object({ query: z.string() });

export class RagService {
  /**
   * RAG検索と回答生成の共通処理
   */
  async processOutputTest(
    question: string,
    options: OutputTestOptions
  ): Promise<RagResponse> {
    const { collectionPath, systemMessage, dataSourceName, fallbackSource } = options;

    const vectorStore = FirestoreVectorStore.fromExistingCollection(
      embeddings,
      collectionPath
    );

    // コレクションにデータが存在するか確認
    const count = await vectorStore.count();
    if (count === 0) {
      throw new Error("ドキュメントが存在しません");
    }

    const retrieve = tool(
      async ({ query }) => {
        const multiQueryRetriever = MultiQueryRetriever.fromLLM({
          llm: model,
          retriever: vectorStore.asRetriever({ k: RETRIEVAL_CONFIG.resultCount }),
          queryCount: 3,
          verbose: true,
        });

        const multiQueryRetrievedDocs =
          await multiQueryRetriever._getRelevantDocuments(query);

        const retrievedResults = multiQueryRetrievedDocs.map(
          // eslint-disable-next-line @typescript-eslint/no-explicit-any
          (doc) => [doc, 0] as [DocumentInterface<Record<string, any>>, number]
        );

        const serialized = retrievedResults
          .map(
            (result) =>
              `Source: ${result[0].metadata.source}\nContent: ${result[0].pageContent}\nScore: ${result[1]}`
          )
          .join("\n");
        return [serialized, retrievedResults];
      },
      {
        name: "retrieve",
        description: `Retrieve information related to a query from ${dataSourceName}.`,
        schema: retrieveSchema,
        responseFormat: "content_and_artifact",
      }
    );

    const agent = createAgent({
      model,
      tools: [retrieve],
      systemPrompt: systemMessage,
    });

    const agentInputs = { messages: [{ role: "user", content: question }] };
    const stream = await agent.stream(agentInputs, { streamMode: "values" });

    let finalAnswer = "";
    let retrievedSources: string[] = [];
    const conversationLog: Array<{ role: string; content: string }> = [];

    for await (const chunk of stream) {
      const lastMessage = chunk.messages[chunk.messages.length - 1];

      conversationLog.push({
        role: lastMessage.role || "unknown",
        content: lastMessage.content,
      });

      if (
        lastMessage.role === "assistant" &&
        lastMessage.content &&
        typeof lastMessage.content === "string" &&
        lastMessage.content.trim()
      ) {
        if (!lastMessage.tool_calls || lastMessage.tool_calls.length === 0) {
          finalAnswer = lastMessage.content;
        }
      }

      for (const message of chunk.messages) {
        if (
          message.role === "assistant" &&
          message.content &&
          typeof message.content === "string" &&
          message.content.trim()
        ) {
          if (!message.tool_calls || message.tool_calls.length === 0) {
            finalAnswer = message.content;
          }
        }
      }

      for (const message of chunk.messages) {
        if (message.role === "tool" && message.content) {
          const sourceMatches = message.content.match(/Source: ([^\n]+)/g);
          if (sourceMatches) {
            sourceMatches.forEach((match: string) => {
              const source = match.replace("Source: ", "").trim();
              if (!retrievedSources.includes(source)) {
                retrievedSources.push(source);
              }
            });
          }
        }
      }

      if (
        lastMessage.role === "assistant" &&
        lastMessage.content &&
        typeof lastMessage.content === "string"
      ) {
        const sourcesInAnswer = lastMessage.content.match(/"sources":\s*\[(.*?)\]/);
        if (sourcesInAnswer) {
          try {
            const sourcesArray = JSON.parse(`[${sourcesInAnswer[1]}]`);
            sourcesArray.forEach((source: string) => {
              const cleanSource = source.replace(/"/g, "").trim();
              if (!retrievedSources.includes(cleanSource)) {
                retrievedSources.push(cleanSource);
              }
            });
          } catch (error) {
            console.warn("Failed to parse sources from answer:", error);
          }
        }
      }
    }

    if (!finalAnswer || finalAnswer.trim() === "") {
      for (let i = conversationLog.length - 1; i >= 0; i--) {
        const log = conversationLog[i];
        if (
          log.role === "assistant" &&
          log.content &&
          typeof log.content === "string" &&
          log.content.trim()
        ) {
          finalAnswer = log.content;
          break;
        }
      }
    }

    if (!finalAnswer || finalAnswer.trim() === "") {
      const lastLog = conversationLog[conversationLog.length - 1];
      if (lastLog && lastLog.content && typeof lastLog.content === "string") {
        finalAnswer = lastLog.content;
      }
    }

    const { structuredAnswer, parsedSuccessfully } = this.parseJsonResponse(
      finalAnswer,
      question,
      retrievedSources,
      fallbackSource
    );

    return {
      question,
      answer: structuredAnswer.answer,
      sources: structuredAnswer.sources,
      conversationLog,
      retrievedContext: retrievedSources.length,
      parsedSuccessfully,
      dataSource: collectionPath,
    };
  }

  private parseJsonResponse(
    finalAnswer: string,
    question: string,
    retrievedSources: string[],
    fallbackSource: string
  ): {
    structuredAnswer: { question: string; answer: string; sources: string[] };
    parsedSuccessfully: boolean;
  } {
    let structuredAnswer;
    let parsedSuccessfully = false;

    try {
      let jsonText = finalAnswer.trim();

      if (jsonText.startsWith("```json") && jsonText.endsWith("```")) {
        jsonText = jsonText.replace(/^```json\n?/, "").replace(/\n?```$/, "").trim();
      } else if (jsonText.startsWith("```") && jsonText.endsWith("```")) {
        jsonText = jsonText.replace(/^```\n?/, "").replace(/\n?```$/, "").trim();
      }

      if (jsonText.startsWith("{") && jsonText.endsWith("}")) {
        structuredAnswer = JSON.parse(jsonText);
        parsedSuccessfully = true;
      } else {
        const jsonMatch = finalAnswer.match(/\{[\s\S]*?\}/);
        if (jsonMatch) {
          structuredAnswer = JSON.parse(jsonMatch[0]);
          parsedSuccessfully = true;
        }
      }

      if (structuredAnswer && (!structuredAnswer.answer || !structuredAnswer.sources)) {
        parsedSuccessfully = false;
      }
    } catch (parseError) {
      console.error("JSON parse error:", parseError);
      parsedSuccessfully = false;
    }

    if (!parsedSuccessfully) {
      structuredAnswer = {
        question,
        answer: finalAnswer || "回答を生成できませんでした。",
        sources: retrievedSources.length > 0 ? retrievedSources : [fallbackSource],
      };
    }

    return { structuredAnswer, parsedSuccessfully };
  }
}
