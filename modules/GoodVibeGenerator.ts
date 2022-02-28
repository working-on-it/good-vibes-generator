import { CosmosDB } from "./CosmosDb";

export class GoodVibeGenerator {
    private static instance: GoodVibeGenerator;
    private config: any;

    private constructor() { }

    public static getInstance(): GoodVibeGenerator {
        if (!this.instance) {
            this.instance = new this();
        }

        return this.instance;
    }

    private async getConfig() {
        const cosmos = CosmosDB.getInstance();
        this.config = await cosmos.getConfig();
    }

    public async getVibe(): Promise<string> {
        // Get config if not already present
        if (!this.config) {
            await this.getConfig();
        }
        return `${this.pickRandomPhrase(this.config.firstPhrases)} ${this.pickRandomPhrase(this.config.secondPhrases)} ${this.pickRandomPhrase(this.config.thirdPhrases)} ${this.pickRandomPhrase(this.config.fourthPhrases)} `;
    }

    private pickRandomPhrase(phrases: string[]): string {
        return phrases[Math.floor(Math.random() * phrases.length)];
    }

}