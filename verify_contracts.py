import pandas as pd
import numpy as np
import re

def clean_team_name(team):
    """Clean team names to match between datasets - use abbreviated names"""
    team = str(team).strip()
    team_mapping = {
        'KC': 'KC','BUF': 'BUF','CIN': 'CIN','JAX': 'JAX','SF': 'SF','LAC': 'LAC','BAL': 'BAL','PHI': 'PHI','DAL': 'DAL','ARI': 'ARI',
        'CLE': 'CLE','NYG': 'NYG','TB': 'TB','MIN': 'MIN','DET': 'DET','GB': 'GB','ATL': 'ATL','IND': 'IND','TEN': 'TEN','NYJ': 'NYJ',
        'DEN': 'DEN','LV': 'LV','NE': 'NE','CHI': 'CHI','HOU': 'HOU','PIT': 'PIT','WAS': 'WAS','SEA': 'SEA','LAR': 'LAR','MIA': 'MIA','CAR': 'CAR'
    }
    return team_mapping.get(team, team)

def clean_test_team_name(team):
    """Clean team names from test data to match contract team names"""
    team = str(team).strip()
    team_mapping = {
        'Cincinnati Bengals': 'CIN','Buffalo Bills': 'BUF','Minnesota Vikings': 'MIN','Baltimore Ravens': 'BAL','Philadelphia Eagles': 'PHI',
        'Cleveland Browns': 'CLE','Dallas Cowboys': 'DAL','San Francisco 49ers': 'SF','Kansas City Chiefs': 'KC','New York N Giants': 'NYG',
        'Tampa Bay Buccaneers': 'TB','Detroit Lions': 'DET','Green Bay Packers': 'GB','Atlanta Falcons': 'ATL','Indianapolis Colts': 'IND',
        'Tennessee Titans': 'TEN','New York A Jets': 'NYJ','Denver Broncos': 'DEN','Las Vegas Raiders': 'LV','New England Patriots': 'NE',
        'Chicago Bears': 'CHI','Houston Texans': 'HOU','Pittsburgh Steelers': 'PIT','Washington Commanders': 'WAS','Seattle Seahawks': 'SEA',
        'Los Angeles N Rams': 'LAR','Miami Dolphins': 'MIA','Carolina Panthers': 'CAR','Los Angeles A Chargers': 'LAC','Arizona Cardinals': 'ARI'
    }
    return team_mapping.get(team, team)

def clean_pfl_team_name(team):
    """Clean team names from PFL data to match test data format"""
    team = str(team).strip()
    team_mapping = {
        'Cincinnati': 'Cincinnati Bengals','Buffalo': 'Buffalo Bills','Minnesota': 'Minnesota Vikings','Baltimore': 'Baltimore Ravens',
        'Philadelphia': 'Philadelphia Eagles','Cleveland': 'Cleveland Browns','Dallas': 'Dallas Cowboys','San Francisco': 'San Francisco 49ers',
        'Kansas City': 'Kansas City Chiefs','New York N': 'New York N Giants','Tampa Bay': 'Tampa Bay Buccaneers','Detroit': 'Detroit Lions',
        'Green Bay': 'Green Bay Packers','Atlanta': 'Atlanta Falcons','Indianapolis': 'Indianapolis Colts','Tennessee': 'Tennessee Titans',
        'New York A': 'New York A Jets','Denver': 'Denver Broncos','Las Vegas': 'Las Vegas Raiders','New England': 'New England Patriots',
        'Chicago': 'Chicago Bears','Houston': 'Houston Texans','Pittsburgh': 'Pittsburgh Steelers','Washington': 'Washington Commanders',
        'Seattle': 'Seattle Seahawks','Los Angeles N': 'Los Angeles N Rams','Miami': 'Miami Dolphins','Carolina': 'Carolina Panthers',
        'Los Angeles A': 'Los Angeles A Chargers','Arizona': 'Arizona Cardinals'
    }
    return team_mapping.get(team, team)

def normalize_name(name: str) -> str:
    """Lowercase, remove spaces/punct, and drop suffixes like Jr., III, II."""
    if pd.isna(name):
        return ''
    s = str(name).lower()
    s = s.replace("'", '').replace('-', '').replace('.', '').replace(' ', '')
    # Remove common suffixes
    for suf in ['jr', 'sr', 'ii', 'iii', 'iv', 'v']:
        if s.endswith(suf):
            s = s[: -len(suf)]
            break
    return s

def normalize_pos_generic(pos: str) -> str:
    """Map various labels to a canonical position set to improve joins."""
    if pd.isna(pos):
        return ''
    p = str(pos).upper().strip()
    mapping = {
        # Defensive front
        'LE': 'DE','RE': 'DE','DE': 'DE',
        'DT': 'DT',
        # Linebackers
        'MLB': 'ILB','ILB': 'ILB','OLB': 'OLB',
        # Secondary
        'FS': 'S','SS': 'S','S': 'S','CB': 'CB',
        # OL
        'LT': 'LT','RT': 'RT','LG': 'G','RG': 'G','G': 'G','C': 'C',
        # Skill offense
        'HB': 'RB','RB': 'RB','WR': 'WR','TE': 'TE','QB': 'QB'
    }
    return mapping.get(p, p)

def extract_contract_value(contract_str):
    """Extract numeric value from currency string (returns raw dollars)."""
    if pd.isna(contract_str) or contract_str == '':
        return 0
    contract_str = str(contract_str).replace('$', '').replace(',', '')
    nums = re.findall(r'\d+\.?\d*', contract_str)
    return float(nums[0]) if nums else 0

def verify_contracts():
    """Verify that PFL players have correct contracts compared to real NFL contracts"""
    
    print("Loading data files for verification...")
    
    # Load the data
    contracts_df = pd.read_csv('NFL Contracts.csv')
    test_df = pd.read_csv('PSFTESTRATINGS.csv')
    pfl_df = pd.read_csv('PFL2025DATA_UPDATED.csv')
    
    print(f"Loaded {len(contracts_df)} contracts, {len(test_df)} test players, {len(pfl_df)} PFL players")
    
    # Clean team names
    contracts_df['Team_Clean'] = contracts_df['Team                     Currently With'].apply(lambda x: clean_team_name(str(x).split()[0]))
    test_df['Team_Clean'] = test_df['Team'].apply(clean_test_team_name)
    pfl_df['Team_Clean'] = pfl_df['Team'].apply(clean_pfl_team_name)
    
    # Normalize names and positions
    contracts_df['name_key'] = contracts_df['Player'].apply(normalize_name)
    test_df['name_key'] = (test_df['firstName'] + ' ' + test_df['lastName']).apply(normalize_name)
    pfl_df['name_key'] = (pfl_df['firstName'] + ' ' + pfl_df['lastName']).apply(normalize_name)
    
    contracts_df['pos_norm'] = contracts_df['Pos'].apply(normalize_pos_generic)
    test_df['pos_norm'] = test_df['Position'].apply(normalize_pos_generic)
    pfl_df['pos_norm'] = pfl_df['Position'].apply(normalize_pos_generic)
    
    # Create match keys
    contracts_df['match_key'] = contracts_df['name_key'] + '_' + contracts_df['Team_Clean'] + '_' + contracts_df['pos_norm']
    test_df['match_key'] = test_df['name_key'] + '_' + test_df['Team_Clean'] + '_' + test_df['pos_norm']
    pfl_df['match_key'] = pfl_df['name_key'] + '_' + pfl_df['Team_Clean'] + '_' + pfl_df['pos_norm']
    
    print("\n=== VERIFICATION RESULTS ===")
    
    # 1. Check how many PFL players have contracts
    pfl_with_contracts = pfl_df[pfl_df['contractTotalValue_M'] > 0]
    print(f"PFL players with contracts: {len(pfl_with_contracts)} out of {len(pfl_df)} ({len(pfl_with_contracts)/len(pfl_df)*100:.1f}%)")
    
    # 2. Verify each PFL player with a contract against real NFL contracts
    verification_results = []
    correct_contracts = 0
    incorrect_contracts = 0
    missing_contracts = 0
    
    for idx, pfl_row in pfl_df.iterrows():
        pfl_name = f"{pfl_row['firstName']} {pfl_row['lastName']}"
        pfl_team = pfl_row['Team_Clean']
        pfl_pos = pfl_row['pos_norm']
        pfl_contract_value = pfl_row['contractTotalValue_M']
        pfl_contract_years = pfl_row['contractYears']
        
        # Find matching real NFL contract
        real_contract = None
        for _, contract_row in contracts_df.iterrows():
            if (contract_row['name_key'] == pfl_row['name_key'] and 
                contract_row['Team_Clean'] == pfl_team and 
                contract_row['pos_norm'] == pfl_pos):
                real_contract = contract_row
                break
        
        if real_contract is not None:
            real_value = extract_contract_value(real_contract['Value'])
            real_years = real_contract['Yrs']
            
            # Check if contract values match
            if (abs(pfl_contract_value - real_value) < 1000 and  # Allow small rounding differences
                pfl_contract_years == real_years):
                correct_contracts += 1
                status = "CORRECT"
            else:
                incorrect_contracts += 1
                status = "INCORRECT"
                
            verification_results.append({
                'PFL_Name': pfl_name,
                'Team': pfl_team,
                'Position': pfl_pos,
                'PFL_Contract_Value': pfl_contract_value,
                'PFL_Contract_Years': pfl_contract_years,
                'Real_Contract_Value': real_value,
                'Real_Contract_Years': real_years,
                'Status': status,
                'Difference': pfl_contract_value - real_value
            })
        else:
            if pfl_contract_value > 0:
                missing_contracts += 1
                status = "NO_REAL_CONTRACT_FOUND"
            else:
                status = "NO_CONTRACT_ASSIGNED"
                
            verification_results.append({
                'PFL_Name': pfl_name,
                'Team': pfl_team,
                'Position': pfl_pos,
                'PFL_Contract_Value': pfl_contract_value,
                'PFL_Contract_Years': pfl_contract_years,
                'Real_Contract_Value': 'N/A',
                'Real_Contract_Years': 'N/A',
                'Status': status,
                'Difference': 'N/A'
            })
    
    # 3. Summary statistics
    print(f"\nContract Verification Summary:")
    print(f"  Correct contracts: {correct_contracts}")
    print(f"  Incorrect contracts: {incorrect_contracts}")
    print(f"  Missing real contracts: {missing_contracts}")
    print(f"  No contract assigned: {len(pfl_df) - len(pfl_with_contracts)}")
    
    if correct_contracts + incorrect_contracts > 0:
        accuracy = correct_contracts / (correct_contracts + incorrect_contracts) * 100
        print(f"  Accuracy: {accuracy:.1f}%")
    
    # 4. Show examples of incorrect contracts
    incorrect_results = [r for r in verification_results if r['Status'] == 'INCORRECT']
    if incorrect_results:
        print(f"\n=== EXAMPLES OF INCORRECT CONTRACTS ===")
        for i, result in enumerate(incorrect_results[:10]):  # Show first 10
            print(f"{i+1}. {result['PFL_Name']} ({result['Team']} {result['Position']})")
            print(f"   PFL: ${result['PFL_Contract_Value']:,.0f} for {result['PFL_Contract_Years']} years")
            print(f"   Real: ${result['Real_Contract_Value']:,.0f} for {result['Real_Contract_Years']} years")
            print(f"   Difference: ${result['Difference']:,.0f}")
            print()
    
    # 5. Show examples of correct contracts
    correct_results = [r for r in verification_results if r['Status'] == 'CORRECT']
    if correct_results:
        print(f"\n=== EXAMPLES OF CORRECT CONTRACTS ===")
        for i, result in enumerate(correct_results[:10]):  # Show first 10
            print(f"{i+1}. {result['PFL_Name']} ({result['Team']} {result['Position']})")
            print(f"   Contract: ${result['PFL_Contract_Value']:,.0f} for {result['PFL_Contract_Years']} years")
            print()
    
    # 6. Save verification results
    verification_df = pd.DataFrame(verification_results)
    output_file = 'contract_verification_results.csv'
    verification_df.to_csv(output_file, index=False)
    print(f"\nDetailed verification results saved to: {output_file}")
    
    return verification_df

if __name__ == "__main__":
    results = verify_contracts()


