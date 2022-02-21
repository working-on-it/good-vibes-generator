import { BaseCosmosItem } from "./BaseCosmosItem";

export interface AppConfig extends BaseCosmosItem {
    firstPhrases: string[];
    secondPhrases: string[];
    thirdPhrases: string[];
    fourthPhrases: string[];
}