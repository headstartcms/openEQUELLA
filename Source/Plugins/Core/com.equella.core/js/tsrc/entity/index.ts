import axios from 'axios';
import { Dispatch } from 'redux';
import { Action, ActionCreator, AsyncActionCreators } from 'typescript-fsa';
import { ReducerBuilder, reducerWithInitialState } from "typescript-fsa-reducers";
import { Entity } from '../api/Entity';
import { SearchResults } from '../api/General';
import { Bridge } from '../api/bridge';
import { Config } from '../config';
import { actionCreator, wrapAsyncWorker } from '../util/actionutil';
import { encodeQuery } from '../util/encodequery';
import { prepLangStrings } from '../util/langstrings';


export function extendedEntityService<E extends Entity, XC extends {}, XW extends {}>(entityType: string, extCrud?: XC, extWorkers?: XW): EntityService<E, XC, XW> {
    const baseActions = entityCrudActions<E>(entityType);
    const baseWorkers = entityWorkers(baseActions);
    const actions: EntityCrudActions<E> & XC = Object.assign({}, baseActions, extCrud);
    const workers: EntityWorkers<E> & XW = Object.assign({}, baseWorkers, extWorkers);

    return {
        actions: actions,
        workers: workers,
        reducer: entityReducerBuilder(baseActions)
    };
}

export function entityService<E extends Entity>(entityType: string): EntityService<E, {}, {}> {
    return extendedEntityService<E, {}, {}>(entityType, {}, {});
}

export const entityStrings = prepLangStrings("entity", {
    edit: {
        tab: {
            permissions: "Permissions"
        }
    }
});

export interface EditEntityStateProps<E extends Entity> {
    entity: E | undefined;
}

export interface EditEntityDispatchProps<E extends Entity> {
    loadEntity: (uuid: string) => Promise<{result: E}>;
    saveEntity: (entity: E) => Promise<{result: E}>;
    modifyEntity: (entity: E) => Action<{entity: E}>;
}

export interface EditEntityProps<E extends Entity> extends EditEntityStateProps<E>, EditEntityDispatchProps<E>
{
    bridge: Bridge;
    uuid?: string;
}

export interface PartialEntityState<E extends Entity> {
    query?: string;
    entities?: E[];
    editingEntity?: E;
    loading?: boolean;
}

export interface EntityState<E extends Entity> extends PartialEntityState<E> {
    entities: E[];
    loading: boolean;
}



interface EntityCrudActions<E extends Entity> {
    entityType: string;
    create: AsyncActionCreators<{entity: E}, {result: E}, void>;
    update: AsyncActionCreators<{entity: E}, {result: E}, void>;
    read: AsyncActionCreators<{uuid: string}, {result: E}, void>;
    delete: AsyncActionCreators<{uuid: string}, {uuid: string}, void>;
    search: AsyncActionCreators<{query: string, privilege: string}, {results: SearchResults<E>}, void>;
    // This is for temp modifications.  E.g. uncommitted changes before save
    modify: ActionCreator<{entity: E}>;
}
  
interface EntityWorkers<E extends Entity> {
    entityType: string;
    create: (dispatch: Dispatch<any>, params: { entity: E; }) => Promise<{ result: E; }>;
    update: (dispatch: Dispatch<any>, params: { entity: E; }) => Promise<{ result: E; }>;
    read: (dispatch: Dispatch<any>, params: { uuid: string; }) => Promise<{ result: E; }>;
    search: (dispatch: Dispatch<any>, params: { query: string; privilege: string }) => Promise<{ results: SearchResults<E>; }>;
}
  
interface EntityService<E extends Entity, XC extends {}, XW extends {}> {
    actions: EntityCrudActions<E> & XC;
    workers: EntityWorkers<E> & XW;
    reducer: ReducerBuilder<PartialEntityState<E>, PartialEntityState<E>>;
}
  
function entityCrudActions<E extends Entity>(entityType: string): EntityCrudActions<E> {
    const createUpdate = actionCreator.async<{entity: E}, {result: E}, void>('SAVE_' + entityType);
    return {
      entityType,
      create: createUpdate,
      update: createUpdate,
      read: actionCreator.async<{uuid: string}, {result: E}, void>('LOAD_' + entityType),
      delete: actionCreator.async<{uuid: string}, {uuid: string}, void>('DELETE_' + entityType),
      search: actionCreator.async<{query: string, privilege: string}, {results: SearchResults<E>}, void>('SEARCH_' + entityType),
      modify: actionCreator<{entity: E}>('MODIFY_' + entityType)
    };
  }
  
function entityWorkers<E extends Entity>(entityCrudActions: EntityCrudActions<E>): any {
    const entityLower = entityCrudActions.entityType.toLowerCase();
    const createUpdate = wrapAsyncWorker(entityCrudActions.update, 
      (param): Promise<{result: E}> => { 
          const { entity } = param;
          if (entity.uuid){
              return axios.put<E>(`${Config.baseUrl}api/${entityLower}/${entity.uuid}`, entity)
                  .then(res => ({ result: res.data})); 
          }
          else {
              return axios.post<E>(`${Config.baseUrl}api/${entityLower}/`, entity)
                  .then(res => ({ result: res.data})); 
          }   
      }
    );
  
    return {
      create: createUpdate,
      update: createUpdate,
      read: wrapAsyncWorker(entityCrudActions.read, 
        (param): Promise<{result: E}> => { 
            const { uuid } = param;
            return axios.get<E>(`${Config.baseUrl}api/${entityLower}/${uuid}`)
                .then(res => ({ result: res.data})); 
        }
      ),
      search: wrapAsyncWorker(entityCrudActions.search, 
        (param): Promise<{results: SearchResults<E>}> => { 
            const { query, privilege } = param;
            const qs = encodeQuery({q: query, privilege})
            return axios.get<SearchResults<E>>(`${Config.baseUrl}api/${entityLower}${qs}`)
                .then(res => ({ results: res.data})); 
        }
      )
    };
}

function entityReducerBuilder<E extends Entity>(entityCrudActions: EntityCrudActions<E>): ReducerBuilder<PartialEntityState<E>, PartialEntityState<E>> {
    let initialEntityState: PartialEntityState<E> = {
        query: '',
        entities: [] as E[],
        loading: false
    };

    return reducerWithInitialState(initialEntityState)
        .case(entityCrudActions.search.started, (state, data) => {
            return state;
        })
        .case(entityCrudActions.search.done, (state, success) => {
            return { ...state, entities: success.result.results.results };
        })
        .case(entityCrudActions.read.started, (state, data) => {
            return state;
        })
        .case(entityCrudActions.read.done, (state, success) => {
            return { ...state, editingEntity: success.result.result };
        })
        .case(entityCrudActions.update.started, (state, data) => {
            return state;
        })
        .case(entityCrudActions.update.done, (state, success) => {
            return state;
        })
        .case(entityCrudActions.modify, (state, payload) => {
            return { ...state, editingEntity: payload.entity }
        });
};