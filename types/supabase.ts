// Supabase database types for my-tracker v1.
// This file mirrors supabase/migrations/0001_init.sql.
// To regenerate from the live schema: `pnpm supabase:types` (requires `supabase login` first).

export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[];

export type FixedExpenseSourceType = 'account' | 'card';
export type InvestmentKind = 'stock' | 'etf' | 'isa' | 'etc';

type Timestamp = string;
type DateString = string;

export interface Database {
  public: {
    Tables: {
      accounts: {
        Row: {
          id: string;
          user_id: string;
          name: string;
          bank: string;
          memo: string | null;
          created_at: Timestamp;
        };
        Insert: {
          id?: string;
          user_id: string;
          name: string;
          bank: string;
          memo?: string | null;
          created_at?: Timestamp;
        };
        Update: {
          id?: string;
          user_id?: string;
          name?: string;
          bank?: string;
          memo?: string | null;
          created_at?: Timestamp;
        };
        Relationships: [];
      };
      cards: {
        Row: {
          id: string;
          user_id: string;
          name: string;
          issuer: string;
          annual_fee: number;
          spending_target: number;
          issued_at: DateString;
          expires_at: DateString | null;
          memo: string | null;
          created_at: Timestamp;
        };
        Insert: {
          id?: string;
          user_id: string;
          name: string;
          issuer: string;
          annual_fee?: number;
          spending_target?: number;
          issued_at: DateString;
          expires_at?: DateString | null;
          memo?: string | null;
          created_at?: Timestamp;
        };
        Update: {
          id?: string;
          user_id?: string;
          name?: string;
          issuer?: string;
          annual_fee?: number;
          spending_target?: number;
          issued_at?: DateString;
          expires_at?: DateString | null;
          memo?: string | null;
          created_at?: Timestamp;
        };
        Relationships: [];
      };
      categories: {
        Row: {
          id: string;
          user_id: string;
          name: string;
          color: string | null;
          created_at: Timestamp;
        };
        Insert: {
          id?: string;
          user_id: string;
          name: string;
          color?: string | null;
          created_at?: Timestamp;
        };
        Update: {
          id?: string;
          user_id?: string;
          name?: string;
          color?: string | null;
          created_at?: Timestamp;
        };
        Relationships: [];
      };
      fixed_expenses: {
        Row: {
          id: string;
          user_id: string;
          name: string;
          amount: number;
          day_of_month: number;
          source_type: FixedExpenseSourceType;
          source_id: string;
          category_id: string | null;
          memo: string | null;
          created_at: Timestamp;
        };
        Insert: {
          id?: string;
          user_id: string;
          name: string;
          amount: number;
          day_of_month: number;
          source_type: FixedExpenseSourceType;
          source_id: string;
          category_id?: string | null;
          memo?: string | null;
          created_at?: Timestamp;
        };
        Update: {
          id?: string;
          user_id?: string;
          name?: string;
          amount?: number;
          day_of_month?: number;
          source_type?: FixedExpenseSourceType;
          source_id?: string;
          category_id?: string | null;
          memo?: string | null;
          created_at?: Timestamp;
        };
        Relationships: [
          {
            foreignKeyName: 'fixed_expenses_category_id_fkey';
            columns: ['category_id'];
            isOneToOne: false;
            referencedRelation: 'categories';
            referencedColumns: ['id'];
          },
        ];
      };
      savings: {
        Row: {
          id: string;
          user_id: string;
          name: string;
          monthly_amount: number;
          start_date: DateString;
          maturity_date: DateString | null;
          memo: string | null;
          created_at: Timestamp;
        };
        Insert: {
          id?: string;
          user_id: string;
          name: string;
          monthly_amount: number;
          start_date: DateString;
          maturity_date?: DateString | null;
          memo?: string | null;
          created_at?: Timestamp;
        };
        Update: {
          id?: string;
          user_id?: string;
          name?: string;
          monthly_amount?: number;
          start_date?: DateString;
          maturity_date?: DateString | null;
          memo?: string | null;
          created_at?: Timestamp;
        };
        Relationships: [];
      };
      investments: {
        Row: {
          id: string;
          user_id: string;
          name: string;
          kind: InvestmentKind;
          initial_principal: number;
          started_at: DateString;
          memo: string | null;
          created_at: Timestamp;
        };
        Insert: {
          id?: string;
          user_id: string;
          name: string;
          kind: InvestmentKind;
          initial_principal: number;
          started_at: DateString;
          memo?: string | null;
          created_at?: Timestamp;
        };
        Update: {
          id?: string;
          user_id?: string;
          name?: string;
          kind?: InvestmentKind;
          initial_principal?: number;
          started_at?: DateString;
          memo?: string | null;
          created_at?: Timestamp;
        };
        Relationships: [];
      };
    };
    Views: Record<string, never>;
    Functions: Record<string, never>;
    Enums: Record<string, never>;
    CompositeTypes: Record<string, never>;
  };
}
