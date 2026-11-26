export interface HelpResource {
  id: string;
  name: string;
  phone: string;
  service: string;
  hours: string;
  primary: boolean;
}

export interface CrisisConfig {
  updatedAt: string;
  reply: string;
  resources: HelpResource[];
}
